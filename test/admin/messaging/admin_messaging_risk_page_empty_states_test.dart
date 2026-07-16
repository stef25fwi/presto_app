import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_risk_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('affiche le résumé et les deux états vides de risque',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminMessagingRiskPage()),
    );
    await tester.pump();

    expect(find.text('Supervision des risques'), findsOneWidget);
    expect(
      find.text(
        'Cette vue regroupe les conversations watchlistées, les scores élevés et les comptes restreints à traiter en priorité.',
      ),
      findsOneWidget,
    );
    expect(find.text('Conversations sensibles'), findsOneWidget);
    expect(find.text('Utilisateurs sensibles'), findsOneWidget);
    expect(
      find.text('Aucune conversation à risque élevé dans le flux récent.'),
      findsOneWidget,
    );
    expect(
      find.text('Aucun utilisateur sensible dans le flux récent.'),
      findsOneWidget,
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
