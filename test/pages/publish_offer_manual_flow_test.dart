import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_category_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_flow_hint.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_mission_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_photos_section.dart';
import 'package:presto_app/pages/publish_offer_page.dart';
import 'package:presto_app/pages/publish_offer_widgets.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final manualButton = find.byKey(const ValueKey('publish-manual-entry'));
  final description = find.byWidgetPredicate(
    (widget) => widget is TextField && (widget.maxLines ?? 1) > 1,
  );
  final title = find.byWidgetPredicate(
    (widget) => widget is TextField &&
        widget.decoration?.hintText == 'Ex : Monter un meuble IKEA',
  );
  const draft = 'Je recherche une personne expérimentée pour repeindre une chambre avec soin.';

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 6200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PublishOfferPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectManual(WidgetTester tester) async {
    await tester.ensureVisible(manualButton);
    await tester.tap(manualButton);
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectInteractive(Finder field) {
    expect(field, findsOneWidget);
    expect(find.ancestor(
      of: field,
      matching: find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
    ), findsNothing);
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }

  testWidgets('sans IA ouvre tous les champs et conserve les validations', (tester) async {
    await pumpPage(tester);
    await selectManual(tester);
    for (final field in [
      description,
      title,
      find.byType(PublishOfferCategoryFields),
      find.byType(PublishOfferPhotosSection),
      find.byType(PublishOfferLocationFields),
      find.byType(PublishOfferPhoneFields),
      find.byType(PublishOfferMissionFields),
      find.widgetWithText(ElevatedButton, 'Publier mon offre'),
    ]) {
      expectInteractive(field);
    }
    expect(tester.widget<TextField>(description).readOnly, isFalse);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Publier mon offre'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final banner = tester.widget<PublishValidationBanner>(find.byType(PublishValidationBanner));
    expect(banner.missingFields, containsAll(['description', 'titre', 'catégorie']));
    expect(find.text('Connecte-toi pour publier'), findsNothing);
    await disposePage(tester);
  });

  testWidgets('formulaire manuel complet rejoint la connexion sans analyse IA', (tester) async {
    await pumpPage(tester);
    await selectManual(tester);
    await tester.enterText(description, draft);
    await tester.enterText(title, 'Repeindre une chambre');
    final category = tester.widget<PublishOfferCategoryFields>(find.byType(PublishOfferCategoryFields));
    category.onCategoryChanged(category.categories.first);
    final location = tester.widget<PublishOfferLocationFields>(find.byType(PublishOfferLocationFields));
    location.cityController.text = 'Les Abymes';
    location.postalCodeController.text = '97139';
    final phone = tester.widget<PublishOfferPhoneFields>(find.byType(PublishOfferPhoneFields));
    phone.controller.text = '0690123456';
    phone.onPhoneChanged('0690123456');
    final mission = tester.widget<PublishOfferMissionFields>(find.byType(PublishOfferMissionFields));
    mission.onDelayChanged('Cette semaine');
    mission.budgetController.text = '45';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Publier mon offre'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Publier mon offre'));
    await tester.pumpAndSettle();
    expect(find.text('Connecte-toi pour publier'), findsOneWidget);
    expect(tester.widget<AiPublishControl>(find.byType(AiPublishControl)).state, AiPublishState.ready);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(description).controller?.text, draft);
    expect(tester.widget<TextField>(title).controller?.text, 'Repeindre une chambre');
    expectInteractive(title);
    await disposePage(tester);
  });

  testWidgets('reprend une description guidée sans effacer le brouillon', (tester) async {
    await pumpPage(tester);
    tester.widget<AiPublishControl>(find.byType(AiPublishControl)).onSelectText();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(description);
    await tester.pump();
    await tester.enterText(description, draft);
    await tester.pump();
    final controller = tester.widget<TextField>(description).controller;
    await selectManual(tester);
    expect(tester.widget<TextField>(description).controller, same(controller));
    expect(controller?.text, draft);
    expectInteractive(title);
    await tester.enterText(title, 'Titre conservé');
    tester.widget<AiWritingButton>(find.byType(AiWritingButton)).onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Connecte-toi pour publier'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expectInteractive(title);
    expect(tester.widget<TextField>(title).controller?.text, 'Titre conservé');
    expect(controller?.text, draft);
    await disposePage(tester);
  });

  testWidgets('réinitialiser annule ou efface explicitement la saisie manuelle', (tester) async {
    await pumpPage(tester);
    await selectManual(tester);
    await tester.enterText(description, draft);
    await tester.tap(find.byTooltip('Réinitialiser tous les champs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(description).controller?.text, draft);
    expect(manualButton, findsNothing);
    await tester.tap(find.byTooltip('Réinitialiser tous les champs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(description).controller?.text, isEmpty);
    expect(manualButton, findsOneWidget);
    await selectManual(tester);
    expectInteractive(title);
    await disposePage(tester);
  });

  testWidgets('entrée manuelle accessible en petit écran et désactivée si occupée', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selections = 0;
    Future<void> render(bool busy) => tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: PublishOfferManualEntry(
          active: false, busy: busy, onSelected: () => selections++,
        ),
      )),
    ));
    await render(true);
    await tester.tap(manualButton);
    expect(selections, 0);
    await render(false);
    await tester.tap(manualButton);
    expect(selections, 1);
    expect(tester.getSize(manualButton).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });
}
