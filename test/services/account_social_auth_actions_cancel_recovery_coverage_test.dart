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

class _RecoveryMultiFactorPlatform extends MultiFactorPlatform {
  _RecoveryMultiFactorPlatform(super.auth);
}

class _RecoveryUserPlatform extends UserPlatform {
  _RecoveryUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _RecoveryMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'recovered-google-user',
              email: 'recovered@ilipresto.fr',
              displayName: 'Recovered User',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 8, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 8, 11).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'bootstrap intentionally unavailable in recovery test',
    );
  }
}

class _CancelThenRecoverAuthPlatform extends FirebaseAuthPlatform {
  _CancelThenRecoverAuthPlatform() : super(appInstance: null) {
    user = _RecoveryUserPlatform(this);
  }

  late final UserPlatform user;
  bool exposeCurrentUser = false;
  var popupCalls = 0;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => exposeCurrentUser ? user : null;

  @override
  Stream<UserPlatform?> authStateChanges() async* {
    exposeCurrentUser = true;
    yield user;
  }

  @override
  Stream<UserPlatform?> userChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Future<UserCredentialPlatform> signInWithPopup(AuthProvider provider) async {
    popupCalls += 1;
    throw FirebaseAuthException(code: 'popup-closed-by-user');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthPlatform originalPlatform;
  late _CancelThenRecoverAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    originalPlatform = FirebaseAuthPlatform.instance;
    platform = _CancelThenRecoverAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform
      ..exposeCurrentUser = false
      ..popupCalls = 0;
  });

  tearDown(() {
    AccountSocialAuthActions.resetTestingOverrides();
    debugDefaultTargetPlatformOverride = null;
  });

  tearDownAll(() {
    FirebaseAuthPlatform.instance = originalPlatform;
  });

  testWidgets(
    'Google récupère une session auth après fermeture du popup',
    (tester) async {
      final previousPlatformOverride = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      try {
        AccountSocialAuthActions.configureWebEnvironmentForTesting(
          isWeb: true,
          baseHost: 'app.ilipresto.fr',
        );

        final completed = Completer<void>();
        String? trackedMethod;
        bool? trackedNewUser;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    try {
                      await AccountSocialAuthActions.signInWithGoogle(
                        context: context,
                        auth: auth,
                        googleAuthService: GoogleAuthService(),
                        trackLogin: ({authMethod, isNewUser = false}) async {
                          trackedMethod = authMethod;
                          trackedNewUser = isNewUser;
                        },
                      );
                      completed.complete();
                    } catch (error, stackTrace) {
                      completed.completeError(error, stackTrace);
                    }
                  },
                  child: const Text('Connexion'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Connexion'));
        await tester.pump();
        await completed.future.timeout(const Duration(seconds: 10));
        await tester.pump();

        expect(platform.popupCalls, 1);
        expect(platform.exposeCurrentUser, isTrue);
        expect(trackedMethod, 'google');
        expect(trackedNewUser, isFalse);
        expect(find.text('Connexion annulée.'), findsNothing);
        expect(find.text('✓ Connecté avec Google'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatformOverride;
        AccountSocialAuthActions.resetTestingOverrides();
      }
    },
  );
}
