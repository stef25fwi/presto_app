import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class _EdgeMultiFactorPlatform extends MultiFactorPlatform {
  _EdgeMultiFactorPlatform(super.auth);
}

class _EdgeAppleUserPlatform extends UserPlatform {
  _EdgeAppleUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _EdgeMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'apple-edge-user',
              email: 'edge@ilipresto.fr',
              displayName: null,
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 20).millisecondsSinceEpoch,
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
      message: 'bootstrap unavailable in deterministic widget test',
    );
  }
}

class _EdgeAppleCredentialPlatform extends UserCredentialPlatform {
  _EdgeAppleCredentialPlatform({
    required super.auth,
    required UserPlatform user,
    required bool isNewUser,
  }) : super(
          user: user,
          additionalUserInfo: AdditionalUserInfo(isNewUser: isNewUser),
        );
}

class _EdgeAppleAuthPlatform extends FirebaseAuthPlatform {
  _EdgeAppleAuthPlatform() : super(appInstance: null) {
    user = _EdgeAppleUserPlatform(this);
  }

  late final _EdgeAppleUserPlatform user;
  bool exposeCurrentUser = true;
  bool isNewUser = true;
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
  UserPlatform? get currentUser => exposeCurrentUser ? user : null;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(currentUser);

  @override
  Future<UserCredentialPlatform> signInWithCredential(
    AuthCredential credential,
  ) async {
    credentialCalls += 1;
    return _EdgeAppleCredentialPlatform(
      auth: this,
      user: user,
      isNewUser: isNewUser,
    );
  }
}

Map<String, Object?> _appleResponse({
  String? givenName,
  String? familyName,
}) {
  return <String, Object?>{
    'type': 'appleid',
    'userIdentifier': 'apple-edge-user',
    'givenName': givenName,
    'familyName': familyName,
    'authorizationCode': 'authorization-code',
    'email': 'edge@ilipresto.fr',
    'identityToken': 'identity-token',
    'state': null,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _EdgeAppleAuthPlatform platform;
  late FirebaseAuth auth;
  late TestDefaultBinaryMessenger messenger;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _EdgeAppleAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  });

  setUp(() {
    platform
      ..exposeCurrentUser = true
      ..isNewUser = true
      ..credentialCalls = 0;
    platform.user.updatedDisplayName = null;
    messenger.setMockMethodCallHandler(
      SignInWithApple.channel,
      (call) async => _appleResponse(familyName: 'Martin'),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SignInWithApple.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> runAction(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final completed = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                await action(context);
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
  }

  testWidgets('Apple construit le nom avec le seul nom de famille',
      (tester) async {
    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {},
      ),
    );

    expect(platform.credentialCalls, 1);
    expect(platform.user.updatedDisplayName, 'Martin');
    expect(find.text('Connecte avec Apple ✓'), findsOneWidget);
  });

  testWidgets('Apple finalise même si currentUser reste momentanément absent',
      (tester) async {
    platform.exposeCurrentUser = false;
    String? trackedMethod;
    bool? trackedNewUser;

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {
          trackedMethod = authMethod;
          trackedNewUser = isNewUser;
        },
      ),
    );

    expect(platform.credentialCalls, 1);
    expect(trackedMethod, 'apple');
    expect(trackedNewUser, isTrue);
    expect(find.text('Connecte avec Apple ✓'), findsOneWidget);
  });

  testWidgets('Apple affiche une erreur déterministe si le tracking échoue',
      (tester) async {
    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {
          throw StateError('tracking indisponible');
        },
      ),
    );

    expect(platform.credentialCalls, 1);
    expect(
      find.textContaining('Erreur inattendue : Bad state: tracking indisponible'),
      findsOneWidget,
    );
  });
}
