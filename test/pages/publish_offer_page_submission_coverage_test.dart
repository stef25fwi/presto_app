import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_category_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_mission_fields.dart';
import 'package:presto_app/pages/publish_offer_page.dart';
import 'package:presto_app/pages/publish_offer_widgets.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 6200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: PublishOfferPage()),
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
      description: 'description détaillée',
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

  ElevatedButton publishButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Publier mon offre'),
    );
  }

  testWidgets('analyse IA vide affiche une aide sans lancer le service',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    final aiButton = tester.widget<AiWritingButton>(
      find.byType(AiWritingButton),
    );
    expect(aiButton.onTap, isNotNull);

    aiButton.onTap!();
    await tester.pump();

    expect(
      find.text("Veuillez d'abord saisir une description"),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('publication vide active les validations et la bannière détaillée',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    publishButton(tester).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final banner = tester.widget<PublishValidationBanner>(
      find.byType(PublishValidationBanner),
    );
    expect(banner.missingFields, isNotEmpty);
    expect(banner.missingFields, contains('description'));
    expect(banner.missingFields, contains('titre'));
    expect(banner.missingFields, contains('catégorie'));
    expect(find.textContaining('Complète les champs mis en évidence'),
        findsOneWidget);
    expect(find.byType(IgnorePointer), findsWidgets);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('formulaire complet non connecté ouvre puis ferme le choix auth',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    final description = descriptionField();
    tester.widget<TextField>(description).onTap?.call();
    await tester.pump();
    await tester.enterText(
      description,
      'Je recherche une personne expérimentée pour repeindre une chambre complète avec soin.',
    );
    await tester.enterText(titleField(), 'Repeindre une chambre');

    final category = tester.widget<PublishOfferCategoryFields>(
      find.byType(PublishOfferCategoryFields),
    );
    category.onCategoryChanged(category.categories.first);

    final location = tester.widget<PublishOfferLocationFields>(
      find.byType(PublishOfferLocationFields),
    );
    location.cityController.text = 'Les Abymes';
    location.postalCodeController.text = '97139';

    final phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    phone.controller.text = '0690123456';
    phone.onPhoneChanged('0690123456');

    final mission = tester.widget<PublishOfferMissionFields>(
      find.byType(PublishOfferMissionFields),
    );
    mission.onDelayChanged('Cette semaine');
    mission.budgetController.text = '45';

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    publishButton(tester).onPressed!();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Connecte-toi pour publier'), findsOneWidget);
    expect(find.text('Je me connecte'), findsOneWidget);
    expect(find.text('Je crée mon compte'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);

    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(find.text('Connecte-toi pour publier'), findsNothing);
    expect(
      tester.widget<TextField>(descriptionField()).controller?.text,
      contains('repeindre une chambre complète'),
    );
    expect(
      tester.widget<TextField>(titleField()).controller?.text,
      'Repeindre une chambre',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
