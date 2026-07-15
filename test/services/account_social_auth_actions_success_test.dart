import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _FakeMultiFactorPlatform extends MultiFactorPlatform {
  _FakeMultiFactorPlatform(super.auth);
}

class _SocialUserPlatform extends UserPlatform {
  _SocialUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _FakeMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'social-user-1',
              email: 'social@ilipresto.fr',
              displayName: 'Alice',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 15).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'test-token';
}

class _SocialCredentialPlatform extends UserCredentialPlatform {
  _SocialCredentialPlatform({
    required super.auth,
    required UserPlatform user,
    required bool isNewUser,
  }) : super(
          user: user,
          additionalUserInfo: AdditionalUserInfo(isNewUser: isNewUser),
        );
}

class _SuccessfulSocialAuthPlatform extends FirebaseAuthPlatform {
  _SuccessfulSocialAuthPlatform() : super(appInstance: null) {
    user = _SocialUserPlatform(this);
  }

  late final UserPlatform user;
  bool isNewUser = true;
  var providerCalls = 0;
  String? providerId;

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
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    providerId = provider.providerId;
    return _SocialCredentialPlatform(
      auth: this,
      user: user,
      isNewUser: isNewUser,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SuccessfulSocialAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _SuccessfulSocialAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform
      ..isNewUser = true
      ..providerCalls = 0
      ..providerId = null;
  });

  Future<void> run(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    final completed = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                try {
                  await action(context);
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
  }

  testWidgets('Google finalise une connexion provider et suit le login',
      (tester) async {
    String? trackedMethod;
    bool? trackedNewUser;

    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, isNewUser = false}) async {
          trackedMethod = authMethod;
          trackedNewUser = isNewUser;
        },
      ),
    );

    expect(platform.providerCalls, 1);
    expect(platform.providerId, 'google.com');
    expect(trackedMethod, 'google');
    expect(trackedNewUser, isTrue);
    expect(find.text('✓ Connecté avec Google'), findsOneWidget);
  });

  testWidgets('Google conserve le succès si le tracking échoue',
      (tester) async {
    platform.isNewUser = false;

    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, isNewUser = false}) async {
          throw StateError('analytics unavailable');
        },
      ),
    );

    expect(find.text('✓ Connecté avec Google'), findsOneWidget);
  });

  testWidgets('Facebook finalise la connexion et transmet isNewUser',
      (tester) async {
    String? trackedMethod;
    bool? trackedNewUser;

    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {
          trackedMethod = authMethod;
          trackedNewUser = isNewUser;
        },
      ),
    );

    expect(platform.providerCalls, 1);
    expect(platform.providerId, 'facebook.com');
    expect(trackedMethod, 'facebook');
    expect(trackedNewUser, isTrue);
    expect(find.text('✓ Connecté avec Facebook'), findsOneWidget);
  });

  testWidgets('Facebook conserve le succès si le tracking échoue',
      (tester) async {
    platform.isNewUser = false;

    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {
          throw StateError('tracking failed');
        },
      ),
    );

    expect(find.text('✓ Connecté avec Facebook'), findsOneWidget);
  });
}
