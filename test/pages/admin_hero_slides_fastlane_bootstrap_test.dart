import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_hero_slides_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:1234567890:web:admin-hero-test',
        messagingSenderId: '1234567890',
        projectId: 'presto-test',
        storageBucket: 'presto-test.appspot.com',
      ),
    );
  });

  testWidgets('affiche la structure admin hero sans blocage au démarrage',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminHeroSlidesPage()),
    );
    await tester.pump();

    expect(find.text('Gestion du Hero'), findsOneWidget);
    expect(find.byTooltip('Ajouter un slide'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find
              .text('Impossible de charger les slides Hero pour le moment.')
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
  });

  testWidgets('conserve une interface stable après plusieurs frames',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminHeroSlidesPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Gestion du Hero'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
