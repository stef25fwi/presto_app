enum AuthGuardDestination { allow, account, verifyEmail }

class AuthGuardPolicy {
  const AuthGuardPolicy();

  AuthGuardDestination resolve({
    required bool signedIn,
    required bool emailVerified,
    required Iterable<String> providerIds,
  }) {
    if (!signedIn) return AuthGuardDestination.account;

    final isPasswordUser = providerIds
        .map((providerId) => providerId.trim().toLowerCase())
        .contains('password');
    if (isPasswordUser && !emailVerified) {
      return AuthGuardDestination.verifyEmail;
    }
    return AuthGuardDestination.allow;
  }
}
