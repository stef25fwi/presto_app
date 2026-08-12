// The platform interface is used only to provide a deterministic Firebase
// Storage delegate while exercising the real Admin Hero editor.
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_hero_slides_page.dart';

class _AdminHeroEditorStoragePlatform extends FirebaseStoragePlatform {
  _AdminHeroEditorStoragePlatform() : super(bucket: 'presto-test.appspot.com');

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

  late FirebaseStoragePlatform originalStoragePlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:admin-hero-editor',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') {
        rethrow;
      }
    }
    originalStoragePlatform = FirebaseStoragePlatform.instance;
  });

  setUp(() {
    FirebaseStoragePlatform.instance = _AdminHeroEditorStoragePlatform();
  });

  tearDown(() {
    FirebaseStoragePlatform.instance = originalStoragePlatform;
  });

  Future<void> pumpAdminHero(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminHeroSlidesPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> openEditor(WidgetTester tester) async {
    final addButton = find.byTooltip('Ajouter un slide');
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ajouter un slide Hero'), findsOneWidget);
  }

  testWidgets(
    'ouvre l éditeur, modifie les états sûrs et valide l absence de média',
    (tester) async {
      await pumpAdminHero(tester);
      await openEditor(tester);

      expect(find.text('Choisir une image ou une vidéo'), findsOneWidget);
      expect(find.text('Titre interne'), findsOneWidget);
      expect(find.text('Durée (secondes)'), findsOneWidget);
      expect(find.text('Ordre'), findsOneWidget);
      expect(find.text('Visibilité du slide'), findsOneWidget);
      expect(find.text('Tout le monde'), findsOneWidget);
      expect(find.text('Une ou plusieurs régions'), findsOneWidget);

      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches, hasLength(2));
      switches[0].onChanged?.call(false);
      switches[1].onChanged?.call(true);
      await tester.pump();

      final globalFinder = find.byWidgetPredicate(
        (widget) => widget is RadioListTile<String> && widget.value == 'global',
      );
      final global = tester.widget<RadioListTile<String>>(globalFinder);
      global.onChanged?.call('global');
      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      await tester.enterText(textFields.at(0), 'Hero test couverture');
      await tester.enterText(textFields.at(1), '12');
      await tester.enterText(textFields.at(2), '3');
      await tester.pump();

      final save = find.text('Enregistrer le slide');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();

      expect(find.text('Ajoutez un fichier image ou vidéo.'), findsOneWidget);
      expect(find.text('Ajouter un slide Hero'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
