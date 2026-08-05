import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _CancelTimeoutAuthPlatform extends FirebaseAuthPlatform {
  _CancelTimeoutAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> authStateController =
      StreamController<UserPlatform?>.broadcast();

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => authStateController.stream;

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();

  @override
  Future<UserCredentialPlatform> signInWithPopup(AuthProvider provider) async {
    throw FirebaseAuthException(code: 'popup-closed-by-user');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CancelTimeoutAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _CancelTimeoutAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  tearDownAll(() async {
    await platform.authStateController.close();
  });

  setUp(() {
    final previousPlatformOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    AccountSocialAuthActions.configureWebEnvironmentForTesting(
      isWeb: true,
      baseHost: 'app.ilipresto.fr',
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatformOverride;
      AccountSocialAuthActions.resetTestingOverrides();
    });
  });

  testWidgets(
    'Google affiche Connexion annulée après le timeout de récupération auth',
    (tester) async {
      final completed = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await AccountSocialAuthActions.signInWithGoogle(
                    context: context,
                    auth: auth,
                    googleAuthService: GoogleAuthService(),
                    trackLogin: ({authMethod, isNewUser = false}) async {},
                  );
                  completed.complete();
                },
                child: const Text('Connexion'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Connexion'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await completed.future;

      expect(find.text('Connexion annulée.'), findsOneWidget);
    },
  );
}
