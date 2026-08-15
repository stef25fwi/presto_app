// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
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

class _FicheProStoragePlatform extends FirebaseStoragePlatform {
  _FicheProStoragePlatform() : super(bucket: 'presto-test.appspot.com');

  @override
  FirebaseStoragePlatform delegateFor({
    required FirebaseApp app,
    required String bucket,
  }) => this;

  @override
  int get maxDownloadRetryTime => 0;

  @override
  int get maxOperationRetryTime => 0;

  @override
  int get maxUploadRetryTime => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthPlatform originalAuthPlatform;
  late FirebaseStoragePlatform originalStoragePlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:fiche-pro-local-coverage',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    originalAuthPlatform = FirebaseAuthPlatform.instance;
    originalStoragePlatform = FirebaseStoragePlatform.instance;
  });

  setUp(() {
    FirebaseAuthPlatform.instance = _SignedOutFicheProAuthPlatform();
    FirebaseStoragePlatform.instance = _FicheProStoragePlatform();
  });

  tearDown(() {
    FirebaseAuthPlatform.instance = originalAuthPlatform;
    FirebaseStoragePlatform.instance = originalStoragePlatform;
  });

  Future<void> pumpOwner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FicheProPage(uid: 'coverage-pro-owner', isOwner: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  testWidgets('propriétaire édite localement toutes les sections principales',
      (tester) async {
    await pumpOwner(tester);

    expect(find.text('Ma fiche Pro'), findsOneWidget);
    expect(find.text('Mon entreprise'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text("Zone d'intervention"), findsOneWidget);
    expect(find.text('Expérience'), findsOneWidget);
    expect(find.text('Disponibilités'), findsOneWidget);
    expect(find.text('Réalisations'), findsOneWidget);
    expect(find.text('Enregistrer ma fiche'), findsOneWidget);

    await tester.tap(find.text('Description'));
    await tester.pump();
    final descriptionField = find.byType(TextField);
    expect(descriptionField, findsOneWidget);
    await tester.enterText(descriptionField, 'Services de bricolage local');
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.text('Services de bricolage local'), findsOneWidget);

    await tester.tap(find.text('Catégories'));
    await tester.pump();
    final categoryField = find.byType(TextField);
    await tester.enterText(categoryField, 'Peinture');
    await tester.tap(find.byTooltip('Ajouter'));
    await tester.pump();
    expect(find.text('Peinture'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.text('Peinture'), findsOneWidget);

    await tester.tap(find.text("Zone d'intervention"));
    await tester.pump();
    final zoneField = find.byType(TextField);
    await tester.enterText(zoneField, 'Basse-Terre');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.text('Basse-Terre'), findsOneWidget);

    await tester.tap(find.text('Expérience'));
    await tester.pump();
    final experienceField = find.byType(TextField);
    await tester.enterText(experienceField, '5 ans');
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.text('5 ans'), findsOneWidget);

    await tester.tap(find.text('Disponibilités'));
    await tester.pump();
    final dispoFields = find.byType(TextField);
    expect(dispoFields, findsNWidgets(2));
    await tester.enterText(dispoFields.at(0), 'Samedi');
    await tester.enterText(dispoFields.at(1), '08:00–12:00');
    await tester.tap(find.byTooltip('Ajouter cette disponibilité'));
    await tester.pump();
    expect(find.textContaining('Samedi'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(find.textContaining('Samedi'), findsOneWidget);

    await tester.tap(find.text('Enregistrer ma fiche'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
