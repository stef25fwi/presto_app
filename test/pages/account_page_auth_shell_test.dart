import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/account/signed_out_account_fallback.dart';
import 'package:presto_app/pages/account_page.dart';

class _AccountAuthPlatform extends FirebaseAuthPlatform {
  _AccountAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> _authController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _idTokenController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _userController =
      StreamController<UserPlatform?>.broadcast();

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => _authController.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => _idTokenController.stream;

  @override
  Stream<UserPlatform?> userChanges() => _userController.stream;

  bool get hasAccountListeners =>
      _authController.hasListener && _idTokenController.hasListener;

  void emitSignedOut() {
    _authController.add(null);
    _idTokenController.add(null);
    _userController.add(null);
  }

  Future<void> disposeControllers() async {
    await _authController.close();
    await _idTokenController.close();
    await _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AccountAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _AccountAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDownAll(() async {
    await authPlatform.disposeControllers();
  });

  Future<void> pumpAccountPage(
    WidgetTester tester, {
    bool startInSignup = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountPage(startInSignup: startInSignup),
      ),
    );
    await tester.pump();
  }

  Future<void> waitForAccountAuthListeners(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame += 1) {
      if (authPlatform.hasAccountListeners) return;
      await tester.pump();
    }
    fail('AccountPage ne s’est pas abonnée aux flux Auth attendus.');
  }

  Future<void> emitSignedOutAndWaitForFallback(WidgetTester tester) async {
    await waitForAccountAuthListeners(tester);
    authPlatform.emitSignedOut();
    for (var frame = 0; frame < 20; frame += 1) {
      await tester.pump();
      if (find.byType(SignedOutAccountFallback).evaluate().isNotEmpty) return;
    }
    fail('Le parcours déconnecté ne s’est pas affiché après l’événement Auth.');
  }

  testWidgets('affiche la restauration tant que le flux Auth ne répond pas',
      (tester) async {
    await pumpAccountPage(tester);
    await waitForAccountAuthListeners(tester);

    expect(find.text('Restauration de la session…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SignedOutAccountFallback), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('route vers la connexion après confirmation de déconnexion',
      (tester) async {
    await pumpAccountPage(tester);
    await emitSignedOutAndWaitForFallback(tester);

    expect(find.text('Connexion à mon compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un nouveau compte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('propage startInSignup au parcours Auth déconnecté',
      (tester) async {
    await pumpAccountPage(tester, startInSignup: true);
    await emitSignedOutAndWaitForFallback(tester);

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Particulier'), findsOneWidget);
    expect(find.text('Entreprise'), findsOneWidget);
    expect(find.text('Créer le compte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('réagit à plusieurs événements Auth déconnectés sans dupliquer UI',
      (tester) async {
    await pumpAccountPage(tester);
    await emitSignedOutAndWaitForFallback(tester);

    authPlatform.emitSignedOut();
    await tester.pump();

    expect(find.byType(SignedOutAccountFallback), findsOneWidget);
    expect(find.text('Connexion à mon compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
