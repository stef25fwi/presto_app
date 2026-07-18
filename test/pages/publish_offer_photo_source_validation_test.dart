import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/main.dart' as app;
import 'package:presto_app/widgets/ai_publish_control.dart';
import 'package:presto_app/widgets/photo_selector_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: app.PublishOfferPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final control = tester.widget<AiPublishControl>(
      find.byType(AiPublishControl),
    );
    control.onSelectText();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> openPhotoSourceSheet(WidgetTester tester) async {
    final tile = tester.widget<PhotoSelectorTile>(
      find.byType(PhotoSelectorTile),
    );
    tile.onTap();
    await tester.pumpAndSettle();
  }

  testWidgets('la galerie ferme la feuille et absorbe l absence du plugin',
      (tester) async {
    await pumpPage(tester);
    await openPhotoSourceSheet(tester);

    expect(find.text('Galerie'), findsOneWidget);
    await tester.tap(find.text('Galerie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Galerie'), findsNothing);
    expect(find.byType(app.PublishOfferPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la caméra ferme la feuille et conserve le formulaire',
      (tester) async {
    await pumpPage(tester);
    await openPhotoSourceSheet(tester);

    expect(find.text('Appareil photo'), findsOneWidget);
    await tester.tap(find.text('Appareil photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Appareil photo'), findsNothing);
    expect(find.text("Photos de l'offre"), findsOneWidget);
    expect(find.byType(PhotoSelectorTile), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
