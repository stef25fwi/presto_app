import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_attachments_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminAttachmentsPage()),
    );
    await tester.pump();
  }

  Future<void> waitForLoadResult(WidgetTester tester) async {
    for (var frame = 0; frame < 30; frame += 1) {
      if (find.text('Réessayer le chargement').evaluate().isNotEmpty ||
          find
              .text('Aucune pièce jointe récente à superviser.')
              .evaluate()
              .isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('Le chargement des pièces jointes ne s’est pas terminé.');
  }

  FilterChip chip(WidgetTester tester, String label) {
    return tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, label),
    );
  }

  testWidgets('affiche le chargement, la recherche et tous les filtres',
      (tester) async {
    await pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Recherche par chemin, conversation, mime type…',
      ),
      findsOneWidget,
    );

    for (final label in const <String>[
      'Tous',
      'approved',
      'manual_review',
      'deleted',
      'image',
      'voice',
      'document',
      'other',
    ]) {
      expect(find.widgetWithText(FilterChip, label), findsOneWidget);
    }

    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'approved').selected, isFalse);

    await waitForLoadResult(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Réessayer le chargement').evaluate().isNotEmpty ||
          find
              .text('Aucune pièce jointe récente à superviser.')
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
  });

  testWidgets('soumet une recherche, change les filtres et relance',
      (tester) async {
    await pumpPage(tester);
    await waitForLoadResult(tester);

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'image/png');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tester.tap(find.text('approved'));
    await tester.pump();
    expect(chip(tester, 'approved').selected, isTrue);
    expect(chip(tester, 'Tous').selected, isFalse);
    await waitForLoadResult(tester);

    await tester.tap(find.text('document'));
    await tester.pump();
    expect(chip(tester, 'document').selected, isTrue);
    expect(chip(tester, 'approved').selected, isFalse);
    await waitForLoadResult(tester);

    await tester.tap(find.text('Tous'));
    await tester.pump();
    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'document').selected, isFalse);
    await waitForLoadResult(tester);

    final retry = find.text('Réessayer le chargement');
    if (retry.evaluate().isNotEmpty) {
      await tester.tap(retry);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await waitForLoadResult(tester);
      expect(find.text('Réessayer le chargement'), findsOneWidget);
    }
  });
}
