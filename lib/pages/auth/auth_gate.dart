import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../account_page.dart';
import 'auth_gate_policy.dart';
import 'verify_email_page.dart';

class AuthGateIdentity {
  const AuthGateIdentity({
    required this.providerIds,
    required this.emailVerified,
  });

  final Iterable<String> providerIds;
  final bool emailVerified;
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.verifiedChild,
    this.policy = const AuthGatePolicy(),
    this.identityChanges,
  });

  final Widget verifiedChild;
  final AuthGatePolicy policy;
  final Stream<AuthGateIdentity?>? identityChanges;

  Stream<AuthGateIdentity?> get _identityChanges {
    final override = identityChanges;
    if (override != null) return override;
    return FirebaseAuth.instance.userChanges().map(
      (user) => user == null
          ? null
          : AuthGateIdentity(
              providerIds: user.providerData.map(
                (provider) => provider.providerId,
              ),
              emailVerified: user.emailVerified,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthGateIdentity?>(
      stream: _identityChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final identity = snapshot.data;
        final destination = policy.resolve(
          signedIn: identity != null,
          providerIds: identity?.providerIds ?? const <String>[],
          emailVerified: identity?.emailVerified ?? false,
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
