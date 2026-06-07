import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/auth/login_page.dart';
import '../pages/auth/verify_email_page.dart';

class AuthGuard {
  const AuthGuard._();

  static Future<bool> requireVerifiedEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!context.mounted) return false;

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

      return false;
    }

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    final isPasswordUser = refreshedUser?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;

    if (isPasswordUser && refreshedUser?.emailVerified != true) {
      if (!context.mounted) return false;

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
      );

      return false;
    }

    return true;
  }
}
