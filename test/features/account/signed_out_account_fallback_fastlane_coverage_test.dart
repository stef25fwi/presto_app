import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/account/signed_out_account_fallback.dart';

class _SignedOutFastLaneAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutFastLaneAuthPlatform() : super(appInstance: null);

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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    FirebaseAuthPlatform.instance = _SignedOutFastLaneAuthPlatform();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    bool startInSignup = false,
    Size size = const Size(1100, 1800),
  }) async {
    tester.view.physicalSize = size;
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

  testWidgets('desktop uses the elevated constrained account card',
      (tester) async {
    await pumpPage(tester);

    final decoratedBoxes = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    final accountCard = decoratedBoxes.firstWhere((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration &&
          decoration.border != null &&
          decoration.color == Colors.white &&
          decoration.borderRadius == BorderRadius.circular(24);
    });
    final decoration = accountCard.decoration as BoxDecoration;

    expect(decoration.borderRadius, BorderRadius.circular(24));
    expect(decoration.boxShadow, isNotEmpty);
    expect(find.text('Connexion à mon compte'), findsOneWidget);
  });

  testWidgets('password reset rejects a malformed email locally',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextFormField).first, 'adresse-invalide');
    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pump();

    expect(find.text('Adresse email invalide.'), findsOneWidget);
  });

  testWidgets('signup validates a password confirmation mismatch',
      (tester) async {
    await pumpPage(tester, startInSignup: true);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), 'Jean');
    await tester.enterText(fields.at(1), 'Dupont');
    await tester.enterText(fields.at(2), 'jean.dupont@example.com');
    await tester.enterText(fields.at(3), 'motdepasse123');
    await tester.enterText(fields.at(4), 'motdepasse456');
    await tester.tap(find.text('Créer le compte'));
    await tester.pump();

    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
  });

  testWidgets('signup validates short identity and password values',
      (tester) async {
    await pumpPage(tester, startInSignup: true);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'J');
    await tester.enterText(fields.at(1), 'D');
    await tester.enterText(fields.at(2), 'email@example.com');
    await tester.enterText(fields.at(3), 'court');
    await tester.enterText(fields.at(4), 'court');
    await tester.tap(find.text('Créer le compte'));
    await tester.pump();

    expect(
      find.text('Le prénom doit contenir au moins 2 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Le nom doit contenir au moins 2 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsNWidgets(2),
    );
  });

  testWidgets('switching auth mode clears the reset error box',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pump();
    expect(find.text('Adresse email invalide.'), findsOneWidget);

    await tester.tap(find.text('Créer un nouveau compte'));
    await tester.pump();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Adresse email invalide.'), findsNothing);
  });
}
