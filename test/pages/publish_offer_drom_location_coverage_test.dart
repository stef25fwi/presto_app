import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/main.dart' as app;
import 'package:presto_app/widgets/ai_publish_control.dart';
import 'package:presto_app/widgets/city_postal_autocomplete_field.dart';

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
      const MaterialApp(home: app.PublishOfferPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final control = tester.widget<AiPublishControl>(
      find.byType(AiPublishControl),
    );
    control.onSelectText();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('synchronise Martinique puis Guyane avec leurs indicatifs',
      (tester) async {
    await pumpPage(tester);

    var location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );

    final martinique = CityEntry(
      name: 'Fort-de-France',
      dept: '972',
      cps: const ['97200'],
      nameNorm: 'fort de france',
    );
    // CityPostalAutocompleteField remplit les deux contrôleurs avant d'appeler
    // le callback parent. Le test reproduit ce contrat sans dépendre du réseau.
    location.cityController.text = martinique.name;
    location.postalCodeController.text = martinique.cps.single;
    location.onCitySelected(martinique);
    await tester.pump();

    location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    var phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(location.cityController.text, 'Fort-de-France');
    expect(location.postalCodeController.text, '97200');
    expect(phone.initialCountryCode, '+596');

    final guyane = CityEntry(
      name: 'Cayenne',
      dept: '973',
      cps: const ['97300'],
      nameNorm: 'cayenne',
    );
    location.cityController.text = guyane.name;
    location.postalCodeController.text = guyane.cps.single;
    location.onCitySelected(guyane);
    await tester.pump();

    location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(location.cityController.text, 'Cayenne');
    expect(location.postalCodeController.text, '97300');
    expect(phone.initialCountryCode, '+594');
    expect(location.postalValidator('97300'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('conserve un code postal saisi lorsqu une ville n en fournit pas',
      (tester) async {
    await pumpPage(tester);

    var location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    location.postalCodeController.text = '97190';

    final guadeloupe = CityEntry(
      name: 'Le Gosier',
      dept: '971',
      cps: const <String>[],
      nameNorm: 'le gosier',
    );
    location.cityController.text = guadeloupe.name;
    location.onCitySelected(guadeloupe);
    await tester.pump();

    location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    final phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(location.cityController.text, 'Le Gosier');
    expect(location.postalCodeController.text, '97190');
    expect(phone.initialCountryCode, '+590');

    location.onPostalTap();
    location.onPostalEditingComplete();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
