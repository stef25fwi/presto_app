enum AuthStatus {
  loading,
  signedOut,
  signedInUnverified,
  signedInVerified,
  disabled,
  error,
}

/// Décision pure de statut d'authentification, indépendante de Firebase.
class AuthStatusPolicy {
  const AuthStatusPolicy();

  AuthStatus resolve({
    required bool signedIn,
    required bool emailVerified,
    required Iterable<String> providerIds,
  }) {
    if (!signedIn) return AuthStatus.signedOut;

    final isPasswordUser = providerIds
        .map((providerId) => providerId.trim().toLowerCase())
        .contains('password');
    if (isPasswordUser && !emailVerified) {
      return AuthStatus.signedInUnverified;
    }
    return AuthStatus.signedInVerified;
  }
}
