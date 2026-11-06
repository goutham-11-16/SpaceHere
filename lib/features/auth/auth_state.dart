class AuthSetupDraft {
  const AuthSetupDraft({
    required this.email,
    required this.vaultPin,
    required this.telegramPhone,
  });

  final String email;
  final String vaultPin;
  final String telegramPhone;
}

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.email,
    required this.telegramPhone,
  });

  const AuthState.unauthenticated()
    : isAuthenticated = false,
      email = null,
      telegramPhone = null;

  final bool isAuthenticated;
  final String? email;
  final String? telegramPhone;
}
