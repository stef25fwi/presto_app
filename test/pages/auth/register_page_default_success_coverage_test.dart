import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/register_page.dart';
import 'package:presto_app/pages/auth/verify_email_page.dart';

class _RegisterMultiFactorPlatform extends MultiFactorPlatform {
  _RegisterMultiFactorPlatform(super.auth);
}

class _RegisterUserPlatform extends UserPlatform {
  _RegisterUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _RegisterMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'register-default-success',
              email: 'register@ilipresto.fr',
              displayName: 'Compte test',
              isAnonymous: false,
              isEmailVerified: false,
              creationTimestamp:
                  DateTime(2026, 7, 23).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 23).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _RegisterAuthPlatform extends FirebaseAuthPlatform {
  _RegisterAuthPlatform() : super(appInstance: null);

  late final UserPlatform user = _RegisterUserPlatform(this);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _RegisterAuthPlatform();
  });

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    );
    return find.descendant(of: decorator, matching: find.byType(EditableText));
  }

  testWidgets('navigue vers VerifyEmailPage avec le builder par défaut',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          registerWithEmail: ({
            required email,
            required password,
            required displayName,
            required fullName,
            required firstName,
            required lastName,
            required pseudo,
          }) async {},
          recordLegalAcceptance: (_) async {},
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(field('Nom *'), 'Durand');
    await tester.enterText(field('Prénom *'), 'Lina');
    await tester.enterText(field('Pseudo'), 'Lina');
    await tester.enterText(field('Email'), 'lina@example.com');
    await tester.enterText(field('Mot de passe'), 'Password1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
