import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_mission_fields.dart';
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
  }

  Future<void> selectTextMode(WidgetTester tester) async {
    final control = tester.widget<AiPublishControl>(
      find.byType(AiPublishControl),
    );
    control.onSelectText();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Finder descriptionField() {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && (widget.maxLines ?? 1) > 1,
      description: 'description multiligne de publication',
    );
  }

  Finder titleField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Ex : Monter un meuble IKEA',
      description: 'titre de publication',
    );
  }

  testWidgets('délai et budget pilotent les décisions réelles du formulaire',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    var mission = tester.widget<PublishOfferMissionFields>(
      find.byType(PublishOfferMissionFields),
    );

    expect(mission.selectedDelay, isNull);
    expect(mission.selectedBudgetType, 'Fixe');
    expect(mission.budgetValidator(''), 'Montant invalide');
    expect(mission.budgetValidator('abc'), 'Montant invalide');
    expect(mission.budgetValidator('0'), 'Le montant doit être > 0');
    expect(mission.budgetValidator('-15'), 'Le montant doit être > 0');
    expect(mission.budgetValidator('1 200,50'), isNull);

    mission.onDelayChanged('Urgent');
    await tester.pump();

    mission = tester.widget<PublishOfferMissionFields>(
      find.byType(PublishOfferMissionFields),
    );
    expect(mission.selectedDelay, 'Urgent');

    mission.onBudgetTypeChanged('À négocier');
    await tester.pump();

    mission = tester.widget<PublishOfferMissionFields>(
      find.byType(PublishOfferMissionFields),
    );
    expect(mission.selectedBudgetType, 'À négocier');
    expect(mission.budgetValidator('texte ignoré'), isNull);

    mission.onBudgetTypeChanged('Fixe');
    await tester.pump();
    expect(
      tester
          .widget<PublishOfferMissionFields>(
            find.byType(PublishOfferMissionFields),
          )
          .selectedBudgetType,
      'Fixe',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('ville DROM, indicatif et confidentialité restent synchronisés',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    var location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    var phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );

    expect(location.postalValidator(''), isNull);
    expect(location.postalValidator('971'), 'Code postal invalide');
    expect(phone.validator(''), 'Téléphone invalide');

    location.onCitySelected(
      CityEntry(
        name: 'Les Abymes',
        dept: '971',
        cps: const ['97139'],
        nameNorm: 'les abymes',
      ),
    );
    await tester.pump();

    phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(phone.initialCountryCode, '+590');

    phone.onCountryCodeChanged('+33');
    await tester.pump();
    phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(phone.initialCountryCode, '+33');

    phone.onHidePhoneChanged(true);
    await tester.pump();
    phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(phone.hidePhone, isTrue);

    phone.onHidePhoneChanged(false);
    await tester.pump();
    expect(
      tester
          .widget<PublishOfferPhoneFields>(
            find.byType(PublishOfferPhoneFields),
          )
          .hidePhone,
      isFalse,
    );

    location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    location.onPostalTap();
    location.onPostalEditingComplete();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('réinitialiser peut être annulé puis efface réellement le brouillon',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    final description = descriptionField();
    final title = titleField();
    expect(description, findsOneWidget);
    expect(title, findsOneWidget);

    final descriptionWidget = tester.widget<TextField>(description);
    descriptionWidget.onTap?.call();
    await tester.pump();

    const descriptionValue =
        'Je recherche une personne soigneuse pour repeindre entièrement une chambre.';
    const titleValue = 'Repeindre une chambre complète';
    await tester.enterText(description, descriptionValue);
    await tester.enterText(title, titleValue);
    await tester.pump();

    await tester.tap(find.byTooltip('Réinitialiser tous les champs'));
    await tester.pump();
    expect(find.text('Réinitialiser ?'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(
      tester.widget<TextField>(descriptionField()).controller?.text,
      descriptionValue,
    );
    expect(
      tester.widget<TextField>(titleField()).controller?.text,
      titleValue,
    );

    await tester.tap(find.byTooltip('Réinitialiser tous les champs'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Réinitialiser'));
    await tester.pump();

    expect(
      tester.widget<TextField>(descriptionField()).controller?.text,
      isEmpty,
    );
    expect(
      tester.widget<TextField>(titleField()).controller?.text,
      isEmpty,
    );

    final mission = tester.widget<PublishOfferMissionFields>(
      find.byType(PublishOfferMissionFields),
    );
    final phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(mission.selectedDelay, isNull);
    expect(mission.selectedBudgetType, 'Fixe');
    expect(phone.hidePhone, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
