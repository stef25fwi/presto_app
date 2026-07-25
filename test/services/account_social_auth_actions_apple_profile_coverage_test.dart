import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class _ProfileMultiFactorPlatform extends MultiFactorPlatform {
  _ProfileMultiFactorPlatform(super.auth);
}

class _ProfileAppleUserPlatform extends UserPlatform {
  _ProfileAppleUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _ProfileMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'apple-profile-user',
              email: 'profile@ilipresto.fr',
              displayName: null,
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 24).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  String? updatedDisplayName;

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    updatedDisplayName = profile['displayName'];
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'bootstrap intentionally unavailable in widget test',
    );
  }
}

class _ProfileAppleCredentialPlatform extends UserCredentialPlatform {
  _ProfileAppleCredentialPlatform({
    required super.auth,
    required UserPlatform user,
  }) : super(
          user: user,
          additionalUserInfo: AdditionalUserInfo(isNewUser: true),
        );
}

class _ProfileAppleAuthPlatform extends FirebaseAuthPlatform {
  _ProfileAppleAuthPlatform() : super(appInstance: null) {
    user = _ProfileAppleUserPlatform(this);
  }

  late final _ProfileAppleUserPlatform user;
  var credentialCalls = 0;

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

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Future<UserCredentialPlatform> signInWithCredential(
    AuthCredential credential,
  ) async {
    credentialCalls += 1;
    return _ProfileAppleCredentialPlatform(auth: this, user: user);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProfileAppleAuthPlatform platform;
  late FirebaseAuth auth;
  late TestDefaultBinaryMessenger messenger;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _ProfileAppleAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  });

  setUp(() {
    platform
      ..credentialCalls = 0
      ..user.updatedDisplayName = null;
    messenger.setMockMethodCallHandler(
      SignInWithApple.channel,
      (_) async => <String, Object?>{
        'type': 'appleid',
        'userIdentifier': 'apple-profile-user',
        'givenName': null,
        'familyName': 'Martin',
        'authorizationCode': 'authorization-code',
        'email': 'profile@ilipresto.fr',
        'identityToken': 'identity-token',
        'state': null,
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SignInWithApple.channel, null);
  });

  testWidgets(
    'Apple utilise le nom de famille seul et tente sa persistance',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final completed = Completer<void>();
      String? trackedMethod;
      bool? trackedNewUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await AccountSocialAuthActions.signInWithApple(
                    context: context,
                    auth: auth,
                    trackLogin: ({authMethod, isNewUser = false}) async {
                      trackedMethod = authMethod;
                      trackedNewUser = isNewUser;
                    },
                  );
                  completed.complete();
                },
                child: const Text('Connexion Apple'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Connexion Apple'));
      await tester.pump();
      await completed.future.timeout(const Duration(seconds: 10));
      await tester.pump();

      expect(platform.credentialCalls, 1);
      expect(platform.user.updatedDisplayName, 'Martin');
      expect(trackedMethod, 'apple');
      expect(trackedNewUser, isTrue);
      expect(find.text('Connecte avec Apple ✓'), findsOneWidget);
    },
  );
}
