import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../account_page.dart';
import 'verify_email_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.verifiedChild,
  });

  final Widget verifiedChild;

  bool _isPasswordUser(User user) {
    return user.providerData
        .any((provider) => provider.providerId == 'password');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const AccountPage();
        }

        if (_isPasswordUser(user) && !user.emailVerified) {
          return const VerifyEmailPage();
        }

        return verifiedChild;
      },
    );
  }
}
