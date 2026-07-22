import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _TestMultiFactorPlatform extends MultiFactorPlatform {
  _TestMultiFactorPlatform(super.auth);
}

class _WebUserPlatform extends UserPlatform {
  _WebUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _TestMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'web-social-user',
              email: 'web@ilipresto.fr',
              displayName: 'Web User',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 22).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'profile bootstrap disabled in deterministic unit tests',
    );
  }
}

class _WebCredentialPlatform extends UserCredentialPlatform {
  _WebCredentialPlatform({
    required super.auth,
    required UserPlatform? user,
    bool isNewUser = false,
  }) : super(
          user: user,
          additionalUserInfo: AdditionalUserInfo(isNewUser: isNewUser),
        );
}

class _WebSocialAuthPlatform extends FirebaseAuthPlatform {
  _WebSocialAuthPlatform() : super(appInstance: null) {
    user = _WebUserPlatform(this);
  }

  late final UserPlatform user;
  bool exposeCurrentUser = false;
  bool popupReturnsUser = false;
  bool popupIsNewUser = false;
  Object? popupError;
  Object? redirectError;
  int popupCalls = 0;
  int redirectCalls = 0;
  String? popupProviderId;
  String? redirectProviderId;

  void reset() {
    exposeCurrentUser = false;
    popupReturnsUser = false;
    popupIsNewUser = false;
    popupError = null;
    redirectError = null;
    popupCalls = 0;
    redirectCalls = 0;
    popupProviderId = null;
    redirectProviderId = null;
  }

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
  Stream<UserPlatform?> userChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Future<UserCredentialPlatform> signInWithPopup(AuthProvider provider) async {
    popupCalls += 1;
    popupProviderId = provider.providerId;
    final failure = popupError;
    if (failure != null) throw failure;
    if (popupReturnsUser) exposeCurrentUser = true;
    return _WebCredentialPlatform(
      auth: this,
      user: popupReturnsUser ? user : null,
      isNewUser: popupIsNewUser,
    );
  }

  @override
  Future<void> signInWithRedirect(AuthProvider provider) async {
    redirectCalls += 1;
    redirectProviderId = provider.providerId;
    final failure = redirectError;
    if (failure != null) throw failure;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _WebSocialAuthPlatform platform;
  late FirebaseAuth auth;
  var rememberedRoutes = 0;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _WebSocialAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform.reset();
    rememberedRoutes = 0;
    AccountSocialAuthActions.configureWebEnvironmentForTesting(
      isWeb: true,
      baseHost: 'app.ilipresto.fr',
      rememberAccountRoute: () async => rememberedRoutes += 1,
    );
  });

  tearDown(AccountSocialAuthActions.resetTestingOverrides);

  Future<void> runAction(
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
    for (var i = 0; i < 20 && !completed.isCompleted; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await completed.future.timeout(const Duration(seconds: 5));
    await tester.pump();
  }

  Future<void> googleAction(BuildContext context) =>
      AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, isNewUser = false}) async {},
      );

  Future<void> facebookAction(BuildContext context) =>
      AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {},
      );

  testWidgets('Google utilise directement redirect sur GitHub Pages',
      (tester) async {
    AccountSocialAuthActions.configureWebEnvironmentForTesting(
      isWeb: true,
      baseHost: 'stef25fwi.github.io',
      rememberAccountRoute: () async => rememberedRoutes += 1,
    );

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 0);
    expect(platform.redirectCalls, 1);
    expect(platform.redirectProviderId, 'google.com');
    expect(rememberedRoutes, 1);
  });

  testWidgets('Google finalise un popup Web réussi', (tester) async {
    platform
      ..popupReturnsUser = true
      ..popupIsNewUser = true;

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 1);
    expect(platform.popupProviderId, 'google.com');
    expect(platform.redirectCalls, 0);
    expect(find.text('✓ Connecté avec Google'), findsOneWidget);
  });

  testWidgets('Google ne redirige pas après fermeture volontaire du popup',
      (tester) async {
    platform.popupError = FirebaseAuthException(code: 'popup-closed-by-user');

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 1);
    expect(platform.redirectCalls, 0);
    expect(find.text('Connexion annulée.'), findsOneWidget);
  });

  testWidgets('Google bascule vers redirect quand le popup est bloqué',
      (tester) async {
    platform.popupError = FirebaseAuthException(code: 'popup-blocked');

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 1);
    expect(platform.redirectCalls, 1);
    expect(rememberedRoutes, 1);
  });

  testWidgets('Google affiche l erreur du redirect de secours', (tester) async {
    platform
      ..popupError = FirebaseAuthException(code: 'popup-blocked')
      ..redirectError = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'offline',
      );

    await runAction(tester, googleAction);

    expect(platform.redirectCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Facebook bascule vers redirect pour un popup bloqué',
      (tester) async {
    platform.popupError = FirebaseAuthException(code: 'popup-blocked');

    await runAction(tester, facebookAction);

    expect(platform.popupCalls, 1);
    expect(platform.popupProviderId, 'facebook.com');
    expect(platform.redirectCalls, 1);
    expect(platform.redirectProviderId, 'facebook.com');
    expect(rememberedRoutes, 1);
  });

  testWidgets('Facebook affiche une erreur Web sans fallback', (tester) async {
    platform.popupError = FirebaseAuthException(
      code: 'network-request-failed',
    );

    await runAction(tester, facebookAction);

    expect(platform.popupCalls, 1);
    expect(platform.redirectCalls, 0);
    expect(
      find.text('Erreur réseau. Vérifie la connexion internet.'),
      findsOneWidget,
    );
  });

  test('helpers de redirection couvrent blocage, COOP et annulation', () {
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        FirebaseAuthException(code: 'popup-blocked'),
      ),
      isTrue,
    );
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'Cross-Origin-Opener-Policy blocked the popup',
        ),
      ),
      isTrue,
    );
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        FirebaseAuthException(code: 'cancelled-popup-request'),
      ),
      isFalse,
    );
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        StateError('popup-blocked-by-browser'),
      ),
      isTrue,
    );
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        StateError('canceled by user'),
      ),
      isFalse,
    );
    expect(
      AccountSocialAuthActions.shouldFallbackToRedirectForTesting(
        StateError('unrelated provider error'),
      ),
      isFalse,
    );
  });

  test('helpers Facebook, nonce, SHA-256 et provider sont déterministes', () {
    expect(
      AccountSocialAuthActions.facebookErrorMessageForTesting(
        FirebaseAuthException(code: 'popup-blocked'),
      ),
      contains('Pop-up Facebook bloquée'),
    );
    expect(
      AccountSocialAuthActions.facebookErrorMessageForTesting(
        FirebaseAuthException(code: 'popup-closed-by-user'),
      ),
      isEmpty,
    );
    expect(
      AccountSocialAuthActions.facebookErrorMessageForTesting(
        StateError('boom'),
      ),
      'Erreur de connexion Facebook. Reessayez.',
    );

    final nonce = AccountSocialAuthActions.generateNonceForTesting(64);
    expect(nonce, hasLength(64));
    expect(RegExp(r'^[0-9A-Za-z._-]+$').hasMatch(nonce), isTrue);
    expect(
      AccountSocialAuthActions.sha256OfStringForTesting('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      AccountSocialAuthActions.buildGoogleProviderForTesting().providerId,
      'google.com',
    );
  });
}
