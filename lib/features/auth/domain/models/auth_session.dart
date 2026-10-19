
class AuthSession {
  final String accessToken;
  final String refreshToken;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
  });

  // We'll use this to check if we have a valid session locally
  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}
