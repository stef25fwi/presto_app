import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_messaging_moderation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('affiche le journal et bascule les quatre filtres',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminMessagingModerationPage()),
    );
    await tester.pump();

    expect(find.text('Modération messages'), findsOneWidget);
    expect(
      find.text('Journal des messages passés en revue, masqués ou refusés.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString().startsWith('SegmentedButton<'),
        description: 'bouton segmenté des filtres de modération',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    for (final label in const ['Tous', 'Pending', 'Revue', 'Refusés']) {
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
