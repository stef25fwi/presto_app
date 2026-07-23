import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/account_page.dart';
import '../pages/auth/verify_email_page.dart';

class AuthGuardIdentity {
  const AuthGuardIdentity({
    required this.providerIds,
    required this.emailVerified,
    required this.reload,
  });

  final Iterable<String> providerIds;
  final bool emailVerified;
  final Future<void> Function() reload;
}

typedef AuthGuardIdentityReader = AuthGuardIdentity? Function();

abstract final class AuthGuard {
  static Future<bool> requireVerifiedEmail(
    BuildContext context, {
    AuthGuardIdentityReader? identityReader,
    WidgetBuilder? accountBuilder,
    WidgetBuilder? verifyEmailBuilder,
  }) async {
    final readIdentity = identityReader ?? _readFirebaseIdentity;
    final initialIdentity = readIdentity();

    if (initialIdentity == null) {
      if (!context.mounted) return false;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: accountBuilder ?? (_) => const AccountPage(),
        ),
      );

      return false;
    }

    await initialIdentity.reload();
    final refreshedIdentity = readIdentity();
    final isPasswordUser = refreshedIdentity?.providerIds.contains('password') ??
        false;

    if (isPasswordUser && refreshedIdentity?.emailVerified != true) {
      if (!context.mounted) return false;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: verifyEmailBuilder ?? (_) => const VerifyEmailPage(),
        ),
      );

      return false;
    }

    return true;
  }

  static AuthGuardIdentity? _readFirebaseIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return AuthGuardIdentity(
      providerIds: user.providerData.map((provider) => provider.providerId),
      emailVerified: user.emailVerified,
      reload: user.reload,
    );
  }
}
