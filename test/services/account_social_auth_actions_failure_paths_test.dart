import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _NullSocialCredentialPlatform extends UserCredentialPlatform {
  _NullSocialCredentialPlatform({required super.auth}) : super(user: null);
}

class _FailureSocialAuthPlatform extends FirebaseAuthPlatform {
  _FailureSocialAuthPlatform() : super(appInstance: null);

  Object? providerError;
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
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    providerId = provider.providerId;
    final error = providerError;
    if (error != null) throw error;
    return _NullSocialCredentialPlatform(auth: this);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FailureSocialAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _FailureSocialAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform
      ..providerError = null
      ..providerCalls = 0
      ..providerId = null;
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
    await tester.pump();
    await completed.future.timeout(const Duration(seconds: 5));
    await tester.pump();
  }

  Future<void> trackLogin({String? authMethod, bool isNewUser = false}) async {}

  testWidgets('Google signale un credential sans utilisateur', (tester) async {
    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: trackLogin,
      ),
    );

    expect(platform.providerCalls, 1);
    expect(platform.providerId, 'google.com');
    expect(
      find.text('Connexion Google incomplete. Reessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('Google traduit une erreur Firebase', (tester) async {
    platform.providerError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'offline',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: trackLogin,
      ),
    );

    expect(platform.providerCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Google traduit une erreur plateforme', (tester) async {
    platform.providerError = PlatformException(
      code: 'sign_in_failed',
      message: 'provider unavailable',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: trackLogin,
      ),
    );

    expect(platform.providerCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Google affiche le repli pour une erreur inattendue',
      (tester) async {
    platform.providerError = StateError('provider unavailable');

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: trackLogin,
      ),
    );

    expect(
      find.text('Erreur lors de la connexion. Réessaye.'),
      findsOneWidget,
    );
  });

  testWidgets('Facebook signale un credential sans utilisateur',
      (tester) async {
    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(platform.providerCalls, 1);
    expect(platform.providerId, 'facebook.com');
    expect(
      find.text('Connexion Facebook incomplete. Reessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('Facebook traduit une erreur Firebase', (tester) async {
    platform.providerError = FirebaseAuthException(
      code: 'operation-not-allowed',
      message: 'disabled',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(
      find.text('Connexion Facebook non activée dans Firebase Authentication.'),
      findsOneWidget,
    );
  });

  testWidgets('Facebook affiche le repli pour une erreur inattendue',
      (tester) async {
    platform.providerError = StateError('provider unavailable');

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(
      find.text('Erreur lors de la connexion Facebook. Reessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('Apple est refusé hors iOS et macOS', (tester) async {
    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(
      find.text('Connexion Apple disponible uniquement sur iOS et macOS.'),
      findsOneWidget,
    );
  });
}
