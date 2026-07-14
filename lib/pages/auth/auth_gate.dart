import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../account_page.dart';
import 'auth_gate_policy.dart';
import 'verify_email_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.verifiedChild,
    this.policy = const AuthGatePolicy(),
  });

  final Widget verifiedChild;
  final AuthGatePolicy policy;

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
        final destination = policy.resolve(
          signedIn: user != null,
          providerIds:
              user?.providerData.map((provider) => provider.providerId) ??
                  const <String>[],
          emailVerified: user?.emailVerified ?? false,
        );

        switch (destination) {
          case AuthGateDestination.account:
            return const AccountPage();
          case AuthGateDestination.verifyEmail:
            return const VerifyEmailPage();
          case AuthGateDestination.verified:
            return verifiedChild;
        }
      },
    );
  }
}
