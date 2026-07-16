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
    await tester.pumpWidget(const MaterialApp(home: AdminAttachmentsPage()));
    await tester.pump();
  }

  FilterChip chip(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilterChip, label));
    await tester.pump();
  }

  testWidgets('affiche le chargement la recherche et tous les filtres',
      (tester) async {
    await pumpPage(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
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
    expect(chip(tester, 'document').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('soumet une recherche et bascule tous les filtres',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'image/png');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tapChip(tester, 'approved');
    expect(chip(tester, 'approved').selected, isTrue);
    expect(chip(tester, 'Tous').selected, isFalse);

    await tapChip(tester, 'manual_review');
    expect(chip(tester, 'manual_review').selected, isTrue);
    expect(chip(tester, 'approved').selected, isFalse);

    await tapChip(tester, 'deleted');
    expect(chip(tester, 'deleted').selected, isTrue);
    expect(chip(tester, 'manual_review').selected, isFalse);

    await tapChip(tester, 'image');
    expect(chip(tester, 'image').selected, isTrue);
    expect(chip(tester, 'deleted').selected, isFalse);

    await tapChip(tester, 'voice');
    expect(chip(tester, 'voice').selected, isTrue);
    expect(chip(tester, 'image').selected, isFalse);

    await tapChip(tester, 'document');
    expect(chip(tester, 'document').selected, isTrue);
    expect(chip(tester, 'voice').selected, isFalse);

    await tapChip(tester, 'other');
    expect(chip(tester, 'other').selected, isTrue);
    expect(chip(tester, 'document').selected, isFalse);

    await tapChip(tester, 'Tous');
    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'other').selected, isFalse);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
