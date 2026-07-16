import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_notifications_monitor_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool showAppBar,
  }) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminNotificationsMonitorPage(showAppBar: showAppBar),
      ),
    );
    await tester.pump();
  }

  FilterChip chip(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilterChip, label));
    await tester.pump();
  }

  testWidgets('affiche l app bar le chargement la recherche et les filtres',
      (tester) async {
    await pumpPage(tester, showAppBar: true);

    expect(find.text('Notifications messagerie'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(
      find.widgetWithText(
        TextField,
        'Recherche par titre, statut, route, conversation…',
      ),
      findsOneWidget,
    );

    for (final label in const ['Tous', 'sent', 'delivered', 'failed']) {
      expect(find.widgetWithText(FilterChip, label), findsOneWidget);
    }

    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'sent').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('masque l app bar soumet la recherche et bascule les filtres',
      (tester) async {
    await pumpPage(tester, showAppBar: false);

    expect(find.text('Notifications messagerie'), findsNothing);

    await tester.enterText(find.byType(TextField), 'conversation-42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tapChip(tester, 'sent');
    expect(chip(tester, 'sent').selected, isTrue);
    expect(chip(tester, 'Tous').selected, isFalse);

    await tapChip(tester, 'delivered');
    expect(chip(tester, 'delivered').selected, isTrue);
    expect(chip(tester, 'sent').selected, isFalse);

    await tapChip(tester, 'failed');
    expect(chip(tester, 'failed').selected, isTrue);
    expect(chip(tester, 'delivered').selected, isFalse);

    await tapChip(tester, 'Tous');
    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'failed').selected, isFalse);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
