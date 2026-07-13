import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/auth_gate.dart';

void main() {
  const account = Text('ACCOUNT_DESTINATION');
  const verify = Text('VERIFY_DESTINATION');
  const verified = Text('VERIFIED_DESTINATION');

  Widget appWith(Stream<AuthGateIdentity?> stream) {
    return MaterialApp(
      home: AuthGate(
        identityChanges: stream,
        accountChild: account,
        verifyEmailChild: verify,
        verifiedChild: verified,
      ),
    );
  }

  testWidgets('affiche le chargement avant la première identité',
      (tester) async {
    final controller = StreamController<AuthGateIdentity?>();
    addTearDown(controller.close);

    await tester.pumpWidget(appWith(controller.stream));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('redirige vers le compte sans identité', (tester) async {
    await tester.pumpWidget(appWith(Stream<AuthGateIdentity?>.value(null)));
    await tester.pump();

    expect(find.text('ACCOUNT_DESTINATION'), findsOneWidget);
  });

  testWidgets('redirige un compte mot de passe non vérifié', (tester) async {
    await tester.pumpWidget(
      appWith(
        Stream<AuthGateIdentity?>.value(
          const AuthGateIdentity(
            providerIds: <String>['password'],
            emailVerified: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VERIFY_DESTINATION'), findsOneWidget);
  });

  testWidgets('autorise un compte mot de passe vérifié', (tester) async {
    await tester.pumpWidget(
      appWith(
        Stream<AuthGateIdentity?>.value(
          const AuthGateIdentity(
            providerIds: <String>['password'],
            emailVerified: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VERIFIED_DESTINATION'), findsOneWidget);
  });

  testWidgets('autorise un compte social', (tester) async {
    await tester.pumpWidget(
      appWith(
        Stream<AuthGateIdentity?>.value(
          const AuthGateIdentity(
            providerIds: <String>['google.com'],
            emailVerified: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VERIFIED_DESTINATION'), findsOneWidget);
  });
}
