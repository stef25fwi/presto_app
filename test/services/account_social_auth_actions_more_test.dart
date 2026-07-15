import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _NullSocialCredential extends UserCredentialPlatform {
  _NullSocialCredential({required super.auth}) : super(user: null);
}

class _ConfigurableSocialAuthPlatform extends FirebaseAuthPlatform {
  _ConfigurableSocialAuthPlatform() : super(appInstance: null);

  Object? error;
  var providerCalls = 0;

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
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    final failure = error;
    if (failure != null) throw failure;
    return _NullSocialCredential(auth: this);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ConfigurableSocialAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _ConfigurableSocialAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform
      ..error = null
      ..providerCalls = 0;
  });

  Widget app(Future<void> Function(BuildContext context) action) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => action(context),
            child: const Text('Connexion'),
          ),
        ),
      ),
    );
  }

  Future<void> run(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    await tester.pumpWidget(app(action));
    await tester.tap(find.text('Connexion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Google refuse un credential sans utilisateur courant', (
    tester,
  ) async {
    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, isNewUser = false}) async {},
      ),
    );

    expect(platform.providerCalls, 1);
    expect(
      find.text('Connexion Google incomplete. Reessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('Facebook refuse un credential sans utilisateur courant', (
    tester,
  ) async {
    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {},
      ),
    );

    expect(platform.providerCalls, 1);
    expect(
      find.text('Connexion Facebook incomplete. Reessayez.'),
      findsOneWidget,
    );
  });

  final expectedMessages = <String, String>{
    'account-exists-with-different-credential':
        'Un compte existe déjà avec cet email. Utilise ta méthode de connexion habituelle.',
    'popup-blocked':
        'Pop-up Facebook bloquée. Autorise les pop-ups puis réessaie.',
    'operation-not-allowed':
        'Connexion Facebook non activée dans Firebase Authentication.',
    'invalid-credential': 'Identifiants Facebook invalides. Réessaie.',
    'network-request-failed': 'Erreur réseau. Vérifie la connexion internet.',
  };

  for (final entry in expectedMessages.entries) {
    testWidgets('Facebook traduit ${entry.key}', (tester) async {
      platform.error = FirebaseAuthException(code: entry.key);

      await run(
        tester,
        (context) => AccountSocialAuthActions.signInWithFacebook(
          context: context,
          auth: auth,
          trackLogin: ({authMethod, isNewUser = false}) async {},
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
    });
  }

  for (final code in <String>[
    'popup-closed-by-user',
    'cancelled-popup-request',
    'cancelled',
  ]) {
    testWidgets('Facebook reste neutre après $code', (tester) async {
      platform.error = FirebaseAuthException(code: code);

      await run(
        tester,
        (context) => AccountSocialAuthActions.signInWithFacebook(
          context: context,
          auth: auth,
          trackLogin: ({authMethod, isNewUser = false}) async {},
        ),
      );

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Erreur de connexion Facebook.'), findsNothing);
    });
  }

  testWidgets('Facebook utilise le message Firebase inconnu', (tester) async {
    platform.error = FirebaseAuthException(
      code: 'unknown',
      message: 'Erreur Facebook distante',
    );

    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {},
      ),
    );

    expect(find.text('Erreur Facebook distante'), findsOneWidget);
  });

  testWidgets('Facebook utilise son repli sans message Firebase', (
    tester,
  ) async {
    platform.error = FirebaseAuthException(code: 'unknown');

    await run(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {},
      ),
    );

    expect(find.text('Erreur de connexion Facebook.'), findsOneWidget);
  });
}
