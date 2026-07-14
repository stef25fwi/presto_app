import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/account/signed_out_account_fallback.dart';

class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAuthPlatform() : super(appInstance: null);

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuthPlatform();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    bool startInSignup = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SignedOutAccountFallback(startInSignup: startInSignup),
      ),
    );
    await tester.pump();
  }

  testWidgets('affiche le parcours de connexion complet', (tester) async {
    await pumpPage(tester);

    expect(find.text('Connexion à mon compte'), findsOneWidget);
    expect(find.text('Adresse email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Créer un nouveau compte'), findsOneWidget);
  });

  testWidgets('bascule entre connexion et création de compte', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Créer un nouveau compte'));
    await tester.pump();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    expect(find.text('Créer le compte'), findsOneWidget);
    expect(find.text('J’ai déjà un compte'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsNothing);

    await tester.tap(find.text('J’ai déjà un compte'));
    await tester.pump();

    expect(find.text('Connexion à mon compte'), findsOneWidget);
  });

  testWidgets('startInSignup ouvre directement le formulaire inscription', (
    tester,
  ) async {
    await pumpPage(tester, startInSignup: true);

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Particulier'), findsOneWidget);
    expect(find.text('Entreprise'), findsOneWidget);
    expect(find.text('Créer le compte'), findsOneWidget);
  });

  testWidgets('le choix entreprise adapte les champs et le bouton', (
    tester,
  ) async {
    await pumpPage(tester, startInSignup: true);

    await tester.tap(find.text('Entreprise'));
    await tester.pump();

    expect(find.text('Nom du contact'), findsOneWidget);
    expect(find.text('Créer le compte entreprise'), findsOneWidget);
    expect(find.text('Prénom'), findsNothing);
    expect(find.text('Nom'), findsNothing);

    await tester.tap(find.text('Particulier'));
    await tester.pump();

    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Créer le compte'), findsOneWidget);
  });

  testWidgets('les boutons de visibilité changent leurs infobulles', (
    tester,
  ) async {
    await pumpPage(tester, startInSignup: true);

    expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
    expect(find.byTooltip('Afficher la confirmation'), findsOneWidget);

    await tester.tap(find.byTooltip('Afficher le mot de passe'));
    await tester.tap(find.byTooltip('Afficher la confirmation'));
    await tester.pump();

    expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
    expect(find.byTooltip('Masquer la confirmation'), findsOneWidget);
  });

  testWidgets('le reset sans email affiche une erreur locale', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pump();

    expect(find.textContaining('email'), findsWidgets);
  });

  testWidgets('la soumission vide déclenche les validateurs', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.textContaining('obligatoire'), findsWidgets);
  });
}
