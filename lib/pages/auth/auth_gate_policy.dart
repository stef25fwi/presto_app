enum AuthGateDestination {
  account,
  verifyEmail,
  verified,
}

/// Décision pure de routage d'authentification.
/// Firebase Auth reste la source d'identité ; cette classe ne fait que traduire
/// son état en destination d'interface testable.
class AuthGatePolicy {
  const AuthGatePolicy();

  AuthGateDestination resolve({
    required bool signedIn,
    required Iterable<String> providerIds,
    required bool emailVerified,
  }) {
    if (!signedIn) return AuthGateDestination.account;

    final isPasswordUser = providerIds
        .map((value) => value.trim().toLowerCase())
        .contains('password');
    if (isPasswordUser && !emailVerified) {
      return AuthGateDestination.verifyEmail;
    }

    return AuthGateDestination.verified;
  }
}
