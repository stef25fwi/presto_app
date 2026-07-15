import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/auth_gate.dart';

class _AuthGatePlatform extends FirebaseAuthPlatform {
  _AuthGatePlatform() : super(appInstance: null);

  Stream<UserPlatform?> changes = Stream<UserPlatform?>.value(null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  Stream<UserPlatform?> userChanges() => changes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('affiche le chargement avant la première identité', (
    tester,
  ) async {
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

  testWidgets('réagit aux transitions successives de session', (tester) async {
    final controller = StreamController<AuthGateIdentity?>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(appWith(controller.stream));

    controller.add(null);
    await tester.pump();
    expect(find.text('ACCOUNT_DESTINATION'), findsOneWidget);

    controller.add(
      const AuthGateIdentity(
        providerIds: <String>['password'],
        emailVerified: false,
      ),
    );
    await tester.pump();
    expect(find.text('VERIFY_DESTINATION'), findsOneWidget);

    controller.add(
      const AuthGateIdentity(
        providerIds: <String>['password'],
        emailVerified: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('VERIFIED_DESTINATION'), findsOneWidget);
  });

  testWidgets('une erreur de flux sans identité revient vers le compte', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(Stream<AuthGateIdentity?>.error(StateError('auth unavailable'))),
    );
    await tester.pump();

    expect(find.text('ACCOUNT_DESTINATION'), findsOneWidget);
  });

  testWidgets('utilise le flux Firebase par défaut quand aucun override existe', (
    tester,
  ) async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final platform = _AuthGatePlatform();
    FirebaseAuthPlatform.instance = platform;

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthGate(
          accountChild: account,
          verifyEmailChild: verify,
          verifiedChild: verified,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ACCOUNT_DESTINATION'), findsOneWidget);
  });
}
