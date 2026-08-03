import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_hero_slides_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FirebaseOptions? originalDefaultOptions;
  var replacedDefaultApp = false;

  const testOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: '1:1234567890:web:admin-hero-permanent',
    messagingSenderId: '1234567890',
    projectId: 'presto-test',
    storageBucket: 'presto-test.appspot.com',
  );

  setUpAll(() async {
    setupFirebaseCoreMocks();

    if (Firebase.apps.isNotEmpty) {
      final defaultApp = Firebase.app();
      final bucket = defaultApp.options.storageBucket;
      if (bucket == null || bucket.trim().isEmpty) {
        originalDefaultOptions = defaultApp.options;
        await defaultApp.delete();
        replacedDefaultApp = true;
      }
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: testOptions);
    }
  });

  tearDownAll(() async {
    if (!replacedDefaultApp) return;

    if (Firebase.apps.isNotEmpty) {
      await Firebase.app().delete();
    }
    final options = originalDefaultOptions;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    }
  });

  Future<void> pumpAdminHero(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminHeroSlidesPage()),
    );
    await tester.pump();
  }

  testWidgets('affiche la structure Admin Hero au démarrage', (tester) async {
    await pumpAdminHero(tester, size: const Size(1000, 1800));

    expect(find.text('Gestion du Hero'), findsOneWidget);
    expect(find.byTooltip('Ajouter un slide'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find
              .text('Impossible de charger les slides Hero pour le moment.')
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reste stable sur une largeur mobile après plusieurs frames',
      (tester) async {
    await pumpAdminHero(tester, size: const Size(430, 1200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Gestion du Hero'), findsOneWidget);
    expect(find.byTooltip('Ajouter un slide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
