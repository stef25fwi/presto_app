import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_audit_logs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminMessagingAuditLogsPage()),
    );
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
        'Recherche par action, cible, admin, motif…',
      ),
      findsOneWidget,
    );

    for (final label in const <String>[
      'Tous',
      'high',
      'medium',
      'normal',
      'update_conversation_status',
      'update_message_report_status',
      'update_user_messaging_status',
    ]) {
      expect(find.widgetWithText(FilterChip, label), findsOneWidget);
    }

    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'high').selected, isFalse);
    expect(chip(tester, 'update_conversation_status').selected, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('soumet une recherche et bascule risques actions puis tous',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'admin@ilipresto.fr');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tapChip(tester, 'high');
    expect(chip(tester, 'high').selected, isTrue);
    expect(chip(tester, 'Tous').selected, isFalse);

    await tapChip(tester, 'medium');
    expect(chip(tester, 'medium').selected, isTrue);
    expect(chip(tester, 'high').selected, isFalse);

    await tapChip(tester, 'normal');
    expect(chip(tester, 'normal').selected, isTrue);
    expect(chip(tester, 'medium').selected, isFalse);

    await tapChip(tester, 'update_conversation_status');
    expect(chip(tester, 'update_conversation_status').selected, isTrue);
    expect(chip(tester, 'normal').selected, isFalse);

    await tapChip(tester, 'update_message_report_status');
    expect(chip(tester, 'update_message_report_status').selected, isTrue);
    expect(chip(tester, 'update_conversation_status').selected, isFalse);

    await tapChip(tester, 'update_user_messaging_status');
    expect(chip(tester, 'update_user_messaging_status').selected, isTrue);
    expect(chip(tester, 'update_message_report_status').selected, isFalse);

    await tapChip(tester, 'Tous');
    expect(chip(tester, 'Tous').selected, isTrue);
    expect(chip(tester, 'update_user_messaging_status').selected, isFalse);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
