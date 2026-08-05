import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/forgot_password_page.dart';

class _ForgotPasswordAuthPlatform extends FirebaseAuthPlatform {
  _ForgotPasswordAuthPlatform() : super(appInstance: null);

  String? languageCodeValue;
  String? resetEmail;
  ActionCodeSettings? resetSettings;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    languageCodeValue = languageCode;
  }

  @override
  Future<void> sendPasswordResetEmail(
    String email, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    resetEmail = email;
    resetSettings = actionCodeSettings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ForgotPasswordAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _ForgotPasswordAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  testWidgets('utilise AuthService par défaut pour envoyer le reset',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordPage(
          successPageBuilder: (email) => Scaffold(
            body: Text('RESET_OK:$email'),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField),
      '  USER@ILIPRESTO.FR  ',
    );
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    expect(platform.languageCodeValue, 'fr');
    expect(platform.resetEmail, 'USER@ILIPRESTO.FR');
    expect(
      platform.resetSettings?.url,
      'https://ilipresto.fr/auth/action',
    );
    expect(find.text('RESET_OK:USER@ILIPRESTO.FR'), findsOneWidget);
  });
}
