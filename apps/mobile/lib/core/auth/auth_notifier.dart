import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import 'auth_state.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage = SecureStorage();

  AuthNotifier(this._apiClient) : super(const AuthState.initial());

  Future<void> checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    final token = await _secureStorage.getAccessToken();
    if (token != null) {
      state = state.copyWith(status: AuthStatus.authenticated, accessToken: token);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _apiClient.dio.post(
        '/api/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];

        // Save tokens securely
        await _secureStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        state = state.copyWith(
          status: AuthStatus.authenticated,
          accessToken: accessToken,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: response.data['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Connection error. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _secureStorage.getAccessToken();
      if (token != null) {
        await _apiClient.dio.post('/api/auth/logout');
      }
    } catch (_) {
      // Ignore network failures on logout and clear locally
    } finally {
      await _secureStorage.clearTokens();
      state = state.copyWith(status: AuthStatus.unauthenticated, accessToken: null);
    }
  }
}
