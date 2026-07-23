import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/register_page.dart';

class _RegisterFailureAuthPlatform extends FirebaseAuthPlatform {
  _RegisterFailureAuthPlatform() : super(appInstance: null);

  String? languageCodeValue;
  String? registeredEmail;
  String? registeredPassword;

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
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    languageCodeValue = languageCode;
  }

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    registeredEmail = email;
    registeredPassword = password;
    throw FirebaseAuthException(code: 'email-already-in-use');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RegisterFailureAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _RegisterFailureAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
    );
    return find.descendant(of: decorator, matching: find.byType(EditableText));
  }

  testWidgets('utilise AuthService.instance quand aucun callback n est injecté',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump();
    await tester.enterText(field('Nom *'), 'Durand');
    await tester.enterText(field('Prénom *'), 'Lina');
    await tester.enterText(field('Pseudo'), 'Lina');
    await tester.enterText(field('Email'), '  lina@example.com  ');
    await tester.enterText(field('Mot de passe'), 'Password1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();

    expect(platform.languageCodeValue, 'fr');
    expect(platform.registeredEmail, 'lina@example.com');
    expect(platform.registeredPassword, 'Password1');
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
