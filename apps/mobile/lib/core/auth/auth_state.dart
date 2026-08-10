enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? accessToken;

  const AuthState({
    required this.status,
    this.errorMessage,
    this.accessToken,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        errorMessage = null,
        accessToken = null;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? accessToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
