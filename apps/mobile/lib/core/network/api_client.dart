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
