import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:presto_app/services/google_auth_service.dart';

class _ThrowingAuthPlatform extends FirebaseAuthPlatform {
  _ThrowingAuthPlatform() : super(appInstance: null);

  Object error = StateError('not configured');

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
    throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ThrowingAuthPlatform authPlatform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _ThrowingAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
    auth = FirebaseAuth.instance;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Widget actionApp(Future<void> Function(BuildContext context) action) {
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

  Future<void> runAction(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    await tester.pumpWidget(actionApp(action));
    await tester.tap(find.text('Connexion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Google mappe une FirebaseAuthException du provider mobile', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    authPlatform.error = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'offline',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, required isNewUser}) async {},
      ),
    );

    expect(find.textContaining('Erreur réseau'), findsOneWidget);
  });

  testWidgets('Google mappe une PlatformException du provider mobile', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    authPlatform.error = const PlatformException(
      code: 'network_error',
      message: 'offline',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, required isNewUser}) async {},
      ),
    );

    expect(find.textContaining('connexion internet'), findsOneWidget);
  });

  testWidgets('Google affiche le fallback pour une erreur inattendue', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    authPlatform.error = StateError('boom');

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: auth,
        googleAuthService: GoogleAuthService(),
        trackLogin: ({authMethod, required isNewUser}) async {},
      ),
    );

    expect(
      find.text('Erreur lors de la connexion. Réessaye.'),
      findsOneWidget,
    );
  });

  testWidgets('Facebook mappe une erreur Firebase connue', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    authPlatform.error = FirebaseAuthException(
      code: 'network-request-failed',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, required isNewUser}) async {},
      ),
    );

    expect(find.textContaining('Erreur réseau'), findsOneWidget);
  });

  testWidgets('Facebook affiche le fallback pour une erreur inattendue', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    authPlatform.error = StateError('boom');

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, required isNewUser}) async {},
      ),
    );

    expect(
      find.text('Erreur lors de la connexion Facebook. Reessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('Apple est refusé hors iOS et macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, required isNewUser}) async {},
      ),
    );

    expect(
      find.text('Connexion Apple disponible uniquement sur iOS et macOS.'),
      findsOneWidget,
    );
  });

  testWidgets('Apple ne navigue pas avec un contexte démonté', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    late BuildContext staleContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            staleContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    await AccountSocialAuthActions.signInWithApple(
      context: staleContext,
      auth: auth,
      trackLogin: ({authMethod, required isNewUser}) async {},
    );

    expect(find.byType(SnackBar), findsNothing);
  });
}
