// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/fiche_pro_page.dart';

class _SignedOutFicheProAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutFicheProAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthPlatform originalAuthPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:fiche-pro-coverage',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    originalAuthPlatform = FirebaseAuthPlatform.instance;
  });

  setUp(() {
    FirebaseAuthPlatform.instance = _SignedOutFicheProAuthPlatform();
  });

  tearDown(() {
    FirebaseAuthPlatform.instance = originalAuthPlatform;
  });

  Future<void> pumpFiche(
    WidgetTester tester, {
    required bool isOwner,
  }) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FicheProPage(uid: 'pro-coverage', isOwner: isOwner),
      ),
    );
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> disposeAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    // Les requêtes publiques possèdent des timeouts de sécurité de 12 s.
    await tester.pump(const Duration(seconds: 13));
  }

  testWidgets('visiteur rend la fiche pro vide sans actions propriétaire',
      (tester) async {
    await pumpFiche(tester, isOwner: false);

    expect(find.text('Fiche Pro'), findsOneWidget);
    expect(find.text('Mon entreprise'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text("Zone d'intervention"), findsOneWidget);
    expect(find.text('Expérience'), findsOneWidget);
    expect(find.text('Disponibilités'), findsOneWidget);
    expect(find.text('Non renseigné'), findsNWidgets(2));
    expect(find.text('Enregistrer ma fiche'), findsNothing);

    await disposeAndFlush(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('propriétaire édite les champs locaux puis tente la sauvegarde',
      (tester) async {
    await pumpFiche(tester, isOwner: true);

    expect(find.text('Ma fiche Pro'), findsOneWidget);
    expect(find.text('Enregistrer ma fiche'), findsOneWidget);
    expect(find.text('Réalisations'), findsOneWidget);

    await tester.tap(find.text('Description'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Description'), findsWidgets);
    final descriptionField = find.byType(TextField).first;
    await tester.enterText(descriptionField, 'Services de proximité');
    await tester.tap(find.text('Confirmer'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Services de proximité'), findsOneWidget);

    await tester.tap(find.text('Catégories'));
    await tester.pump(const Duration(milliseconds: 200));
    final categoryField = find.byType(TextField).first;
    await tester.enterText(categoryField, 'Bricolage');
    await tester.tap(find.byTooltip('Ajouter'));
    await tester.pump();
    expect(find.text('Bricolage'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Bricolage'), findsOneWidget);

    await tester.tap(find.text('Expérience'));
    await tester.pump(const Duration(milliseconds: 200));
    final experienceField = find.byType(TextField).first;
    await tester.enterText(experienceField, '5 ans');
    await tester.tap(find.text('Confirmer'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('5 ans'), findsOneWidget);

    await tester.tap(find.text('Disponibilités'));
    await tester.pump(const Duration(milliseconds: 200));
    final dispoFields = find.byType(TextField);
    expect(dispoFields, findsNWidgets(2));
    await tester.enterText(dispoFields.at(0), 'Lundi');
    await tester.enterText(dispoFields.at(1), '08h-12h');
    await tester.tap(find.byTooltip('Ajouter cette disponibilité'));
    await tester.pump();
    expect(find.textContaining('Lundi'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Lundi'), findsOneWidget);

    // Sans utilisateur connecté, _save retourne immédiatement : branche locale
    // déterministe, sans écriture Firestore ni contournement du comportement.
    await tester.tap(find.text('Enregistrer ma fiche'));
    await tester.pump();

    await disposeAndFlush(tester);
    expect(tester.takeException(), isNull);
  });
}
