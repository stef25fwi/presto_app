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

  Future<void> pumpCenter(
    WidgetTester tester, {
    required Size size,
    AdminMessagingSection initialSection = AdminMessagingSection.risk,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMessagingCenterPage(initialSection: initialSection),
      ),
    );
    await tester.pump();
  }

  Future<void> selectChip(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('le sélecteur compact ouvre les dix sections', (tester) async {
    await pumpCenter(tester, size: const Size(900, 2200));

    expect(find.byType(ChoiceChip), findsNWidgets(10));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Gestion messagerie - Risque'), findsOneWidget);
    expect(find.text('Supervision des risques'), findsOneWidget);

    const sections = <(String, String)>[
      ('Vue d\'ensemble', 'Gestion messagerie - Vue d\'ensemble'),
      ('Conversations', 'Gestion messagerie - Conversations'),
      ('Signalements', 'Gestion messagerie - Signalements'),
      ('Risque', 'Gestion messagerie - Risque'),
      ('Utilisateurs', 'Gestion messagerie - Utilisateurs'),
      ('Pièces jointes', 'Gestion messagerie - Pièces jointes'),
      ('Notifications', 'Gestion messagerie - Notifications'),
      ('Paramètres', 'Gestion messagerie - Paramètres'),
      ('Audit', 'Gestion messagerie - Audit'),
      ('Analytics', 'Gestion messagerie - Analytics'),
    ];

    for (final section in sections) {
      await selectChip(tester, section.$1);
      expect(find.text(section.$2), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('le rail large sélectionne une autre section', (tester) async {
    await pumpCenter(tester, size: const Size(1400, 2400));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(rail.selectedIndex, AdminMessagingSection.risk.index);
    expect(find.text('Gestion messagerie - Risque'), findsOneWidget);

    await tester.tap(find.text('Paramètres'));
    await tester.pump();

    expect(find.text('Gestion messagerie - Paramètres'), findsOneWidget);
    final updatedRail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(updatedRail.selectedIndex, AdminMessagingSection.settings.index);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
