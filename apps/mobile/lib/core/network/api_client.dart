import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  final Dio dio;
  final SecureStorage _secureStorage = SecureStorage();

  ApiClient() : dio = Dio(BaseOptions(
          baseUrl: AppConfig.baseApiUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        )) {
    dio.interceptors.add(HttpCacheInterceptor());
    dio.interceptors.add(DeduplicationInterceptor());
    _initializeInterceptors();
  }

  void _initializeInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Version header requirement
          options.headers['X-App-Version'] = AppConfig.appVersion;

          // 2. Token injection
          final token = await _secureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // 3. Catch unauthorized 401 codes to refresh tokens
          if (error.response?.statusCode == 401) {
            final refreshToken = await _secureStorage.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Request new access tokens from the API
                final refreshResponse = await Dio().post(
                  '${AppConfig.baseApiUrl}/api/auth/refresh',
                  data: {'refreshToken': refreshToken},
                  options: Options(headers: {'X-App-Version': AppConfig.appVersion}),
                );

                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['data']['accessToken'];
                  final newRefreshToken = refreshResponse.data['data']['refreshToken'];

                  // Cache the new credentials
                  await _secureStorage.saveTokens(
                    accessToken: newAccessToken,
                    refreshToken: newRefreshToken,
                  );

                  // Update header and retry the original failed request
                  final options = error.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccessToken';

                  final retryResponse = await dio.fetch(options);
                  return handler.resolve(retryResponse);
                }
              } catch (e) {
                // If refresh token fails/expired, clear storage and log out
                await _secureStorage.clearTokens();
              }
            } else {
              await _secureStorage.clearTokens();
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Logging in development only
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
      ));
    }
  }
}

class DeduplicationInterceptor extends Interceptor {
  final Map<String, List<Completer<Response>>> _pending = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method != 'GET') {
      return handler.next(options);
    }

    final key = '${options.uri.toString()}?${options.queryParameters.toString()}';

    if (_pending.containsKey(key)) {
      final completer = Completer<Response>();
      _pending[key]!.add(completer);
      completer.future.then((response) {
        handler.resolve(response);
      }).catchError((err) {
        if (err is DioException) {
          handler.reject(err);
        } else {
          handler.reject(DioException(
            requestOptions: options,
            error: err,
          ));
        }
      });
      return;
    }

    _pending[key] = [];
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method != 'GET') {
      return handler.next(response);
    }

    final key = '${response.requestOptions.uri.toString()}?${response.requestOptions.queryParameters.toString()}';
    final completers = _pending.remove(key);

    if (completers != null) {
      for (final completer in completers) {
        completer.complete(response);
      }
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.method != 'GET') {
      return handler.next(err);
    }

    final key = '${err.requestOptions.uri.toString()}?${err.requestOptions.queryParameters.toString()}';
    final completers = _pending.remove(key);

    if (completers != null) {
      for (final completer in completers) {
        completer.completeError(err);
      }
    }

    handler.next(err);
  }
}

class CachedResponse {
  final Response response;
  final DateTime timestamp;
  final Duration ttl;

  CachedResponse({
    required this.response,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(timestamp.add(ttl));
}

class HttpCacheInterceptor extends Interceptor {
  static final Map<String, CachedResponse> _cache = {};

  static void clear() {
    _cache.clear();
  }

  static void invalidatePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.contains(prefix));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method != 'GET') {
      // Invalidate related caches on mutations (POST, PUT, DELETE, PATCH)
      final path = options.path;
      invalidatePrefix(path);
      return handler.next(options);
    }

    final noCache = options.extra['no-cache'] == true ||
        options.headers['Cache-Control'] == 'no-cache';
    if (noCache) {
      return handler.next(options);
    }

    final key =
        '${options.uri.toString()}?${options.queryParameters.toString()}';
    final cached = _cache[key];

    if (cached != null && !cached.isExpired) {
      // Return fresh copy of cached response without network roundtrip
      return handler.resolve(
        Response(
          requestOptions: options,
          data: cached.response.data,
          statusCode: cached.response.statusCode,
          statusMessage: cached.response.statusMessage,
          headers: cached.response.headers,
          isRedirect: cached.response.isRedirect,
          redirects: cached.response.redirects,
          extra: {'from_cache': true},
        ),
      );
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method == 'GET' && response.statusCode == 200) {
      final cacheControl = response.headers.value('cache-control') ?? '';

      if (!cacheControl.contains('no-store') &&
          !cacheControl.contains('no-cache')) {
        int maxAgeSeconds = 30; // default 30s
        final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
        if (match != null) {
          maxAgeSeconds = int.tryParse(match.group(1) ?? '30') ?? 30;
        }

        if (maxAgeSeconds > 0) {
          final key =
              '${response.requestOptions.uri.toString()}?${response.requestOptions.queryParameters.toString()}';
          _cache[key] = CachedResponse(
            response: response,
            timestamp: DateTime.now(),
            ttl: Duration(seconds: maxAgeSeconds),
          );
        }
      }
    }

    handler.next(response);
  }
}

