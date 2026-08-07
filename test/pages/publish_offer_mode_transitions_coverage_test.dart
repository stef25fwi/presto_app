import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_mission_fields.dart';
import 'package:presto_app/pages/publish_offer_page.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: PublishOfferPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets(
    'les transitions vocal texte vocal pilotent réellement le formulaire',
    (tester) async {
      await pumpPage(tester);

      var control = tester.widget<AiPublishControl>(
        find.byType(AiPublishControl),
      );
      expect(control.state, AiPublishState.ready);

      control.onSelectText();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      control = tester.widget<AiPublishControl>(
        find.byType(AiPublishControl),
      );
      expect(control.state, AiPublishState.ready);
      expect(find.byType(PublishOfferMissionFields), findsOneWidget);

      control.onSelectVocal();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      control = tester.widget<AiPublishControl>(
        find.byType(AiPublishControl),
      );
      expect(control.state, AiPublishState.ready);

      control.onSelectText();
      await tester.pump();
      expect(find.byType(PublishOfferMissionFields), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
