import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_center_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpSection(
    WidgetTester tester,
    AdminMessagingSection section,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingCenterPage(initialSection: section),
      ),
    );
    await tester.pump();
  }

  FilterChip chip(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

  Future<void> tapChip(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(FilterChip, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> submitSearch(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('filtre les conversations par statut et watchlist',
      (tester) async {
    await pumpSection(tester, AdminMessagingSection.conversations);

    expect(find.text('Conversations récentes'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Recherche par annonce, participant, statut, région…',
      ),
      findsOneWidget,
    );
    await submitSearch(tester, 'jardinage');

    expect(chip(tester, 'Tous statuts').selected, isTrue);
    for (final label in const ['active', 'reported', 'closed']) {
      await tapChip(tester, label);
      expect(chip(tester, label).selected, isTrue);
      expect(chip(tester, 'Tous statuts').selected, isFalse);
    }

    await tapChip(tester, 'Watchlist');
    expect(chip(tester, 'Watchlist').selected, isTrue);
    expect(chip(tester, 'closed').selected, isFalse);

    await tapChip(tester, 'Tous statuts');
    expect(chip(tester, 'Tous statuts').selected, isTrue);
    expect(chip(tester, 'Watchlist').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('filtre les signalements par statut et priorité', (tester) async {
    await pumpSection(tester, AdminMessagingSection.reports);

    expect(find.text('Signalements messagerie'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Recherche par motif, priorité, statut, utilisateur…',
      ),
      findsOneWidget,
    );
    await submitSearch(tester, 'contenu inapproprié');

    expect(chip(tester, 'Tous').selected, isTrue);
    for (final label in const ['nouveau', 'en revue', 'résolu']) {
      await tapChip(tester, label);
      expect(chip(tester, label).selected, isTrue);
    }

    await tapChip(tester, 'critique');
    expect(chip(tester, 'critique').selected, isTrue);
    expect(chip(tester, 'résolu').selected, isFalse);

    await tapChip(tester, 'haute');
    expect(chip(tester, 'haute').selected, isTrue);
    expect(chip(tester, 'critique').selected, isFalse);

    await tapChip(tester, 'Tous');
    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'haute').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('filtre les utilisateurs par statut et rôle', (tester) async {
    await pumpSection(tester, AdminMessagingSection.users);

    expect(find.text('Utilisateurs messagerie'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Recherche par nom, email, rôle, région, statut…',
      ),
      findsOneWidget,
    );
    await submitSearch(tester, 'prestataire');

    expect(chip(tester, 'Tous').selected, isTrue);
    for (final label in const ['actif', 'bloqué', 'suspendu', 'restreint']) {
      await tapChip(tester, label);
      expect(chip(tester, label).selected, isTrue);
    }

    for (final label in const ['prestataire', 'pro', 'user']) {
      await tapChip(tester, label);
      expect(chip(tester, label).selected, isTrue);
    }
    expect(chip(tester, 'restreint').selected, isFalse);

    await tapChip(tester, 'Tous');
    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'user').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
