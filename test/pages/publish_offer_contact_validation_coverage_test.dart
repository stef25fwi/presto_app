import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/main.dart' as app;
import 'package:presto_app/widgets/ai_publish_control_with_credits.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpTextForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: app.PublishOfferPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final control = tester.widget<AiPublishControl>(find.byType(AiPublishControl));
    control.onSelectText();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('valide le téléphone et synchronise indicatif et saisie',
      (tester) async {
    await pumpTextForm(tester);

    var fields = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );

    expect(fields.validator(''), isNotNull);
    expect(fields.validator('690123456'), isNull);

    fields.onCountryCodeChanged('+590');
    fields.controller.text = '690 12 34 56';
    fields.onPhoneChanged(fields.controller.text);
    await tester.pump();

    fields = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(fields.initialCountryCode, '+590');
    expect(fields.controller.text, '690 12 34 56');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('exécute les validations du code postal', (tester) async {
    await pumpTextForm(tester);

    final location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );

    expect(location.postalValidator(''), isNull);
    expect(location.postalValidator('97122'), isNull);
    expect(location.postalValidator('123'), isNotNull);

    location.onPostalTap();
    location.postalCodeController.text = '97122';
    location.onPostalEditingComplete();
    await tester.pump();

    expect(location.postalCodeController.text, '97122');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
