import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _GapMultiFactorPlatform extends MultiFactorPlatform {
  _GapMultiFactorPlatform(super.auth);
}

class _GapUserPlatform extends UserPlatform {
  _GapUserPlatform(FirebaseAuthPlatform auth)
    : super(
        auth,
        _GapMultiFactorPlatform(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'gap-web-user',
            email: 'gap@ilipresto.fr',
            displayName: 'Gap User',
            isAnonymous: false,
            isEmailVerified: true,
            creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
            lastSignInTimestamp: DateTime(2026, 7, 23).millisecondsSinceEpoch,
          ),
          providerData: const <Map<String, dynamic>?>[],
        ),
      );

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'profile bootstrap disabled in deterministic tests',
    );
  }
}

class _GapCredentialPlatform extends UserCredentialPlatform {
  _GapCredentialPlatform({
    required super.auth,
    required super.user,
    bool isNewUser = false,
  }) : super(
         additionalUserInfo: AdditionalUserInfo(isNewUser: isNewUser),
       );
}

class _GapSocialAuthPlatform extends FirebaseAuthPlatform {
  _GapSocialAuthPlatform() : super(appInstance: null) {
    user = _GapUserPlatform(this);
  }

  late final UserPlatform user;
  final StreamController<UserPlatform?> authStateController =
      StreamController<UserPlatform?>.broadcast();

  bool exposeCurrentUser = false;
  bool popupReturnsUser = false;
  bool popupIsNewUser = false;
  bool authStateNeverCompletes = false;
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
    authStateNeverCompletes = false;
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
  }) => this;

  @override
  UserPlatform? get currentUser => exposeCurrentUser ? user : null;

  @override
  Stream<UserPlatform?> authStateChanges() {
    if (authStateNeverCompletes) return authStateController.stream;
    return Stream<UserPlatform?>.value(currentUser);
  }

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
    return _GapCredentialPlatform(
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

  late _GapSocialAuthPlatform platform;
  late FirebaseAuth auth;
  var rememberedRoutes = 0;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _GapSocialAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  tearDownAll(() async {
    await platform.authStateController.close();
  });

  setUp(() {
    platform.reset();
    rememberedRoutes = 0;
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    AccountSocialAuthActions.configureWebEnvironmentForTesting(
      isWeb: true,
      baseHost: 'app.ilipresto.fr',
      rememberAccountRoute: () async => rememberedRoutes += 1,
    );
  });

  tearDown(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    AccountSocialAuthActions.resetTestingOverrides();
  });

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
    for (var i = 0; i < 45 && !completed.isCompleted; i += 1) {
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

  testWidgets('Google affiche l erreur du redirect direct GitHub Pages', (
    tester,
  ) async {
    AccountSocialAuthActions.configureWebEnvironmentForTesting(
      isWeb: true,
      baseHost: 'stef25fwi.github.io',
    );
    platform.redirectError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'offline',
    );

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 0);
    expect(platform.redirectCalls, 1);
    expect(platform.redirectProviderId, 'google.com');
    expect(rememberedRoutes, 0);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Google gère le timeout authStateChanges sans session', (
    tester,
  ) async {
    platform.authStateNeverCompletes = true;

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 1);
    expect(platform.redirectCalls, 0);
    expect(
      find.text('Connexion Google incomplete. Reessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('Google affiche une erreur Web sans fallback redirect', (
    tester,
  ) async {
    platform.popupError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'offline',
    );

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 1);
    expect(platform.redirectCalls, 0);
    expect(find.textContaining('Erreur réseau'), findsOneWidget);
  });

  testWidgets('Google tente le redirect malgré un App Check indisponible', (
    tester,
  ) async {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;
    platform.popupError = FirebaseAuthException(code: 'popup-blocked');

    await runAction(tester, googleAction);

    expect(platform.popupCalls, 1);
    expect(platform.redirectCalls, 1);
    expect(rememberedRoutes, 1);
  });

  testWidgets('Facebook finalise un popup Web réussi', (tester) async {
    platform
      ..popupReturnsUser = true
      ..popupIsNewUser = true;

    await runAction(tester, facebookAction);

    expect(platform.popupCalls, 1);
    expect(platform.popupProviderId, 'facebook.com');
    expect(platform.redirectCalls, 0);
    expect(find.text('✓ Connecté avec Facebook'), findsOneWidget);
  });
}
