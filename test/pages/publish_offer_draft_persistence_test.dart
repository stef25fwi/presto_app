import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_mission_fields.dart';
import 'package:presto_app/pages/publish_offer_page.dart';
import 'package:presto_app/services/publish_offer_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryPublishOfferDraftStore extends PublishOfferDraftStore {
  _MemoryPublishOfferDraftStore(this.draft);

  PublishOfferDraft? draft;

  @override
  Future<void> save(PublishOfferDraft value) async {
    draft = value.hasMeaningfulContent ? value : null;
  }

  @override
  Future<PublishOfferDraft?> loadForOwner(String rawOwnerId) async {
    final ownerId = rawOwnerId.trim();
    final currentDraft = draft;
    if (currentDraft?.ownerId == ownerId) return currentDraft;
    draft = null;
    return null;
  }

  @override
  Future<void> clearForOwner(String rawOwnerId) async {
    if (draft?.ownerId == rawOwnerId.trim()) {
      draft = null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Finder titleField() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Ex : Monter un meuble IKEA',
      description: 'titre de publication',
    );
  }

  Finder descriptionField() {
    return find.byWidgetPredicate(
      (widget) => widget is TextField && (widget.maxLines ?? 1) > 1,
      description: 'description de publication',
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    PublishOfferDraftStore store,
  ) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(
          draftStoreForTesting: store,
          draftOwnerIdForTesting: 'user-971',
        ),
      ),
    );
    for (var frame = 0; frame < 20; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .text('Saisie manuelle activée · Aide IA facultative')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
  }

  testWidgets('restaure le brouillon et sauvegarde les modifications',
      (tester) async {
    final store = _MemoryPublishOfferDraftStore(
      PublishOfferDraft(
        ownerId: 'user-971',
        savedAt: DateTime.now(),
        title: 'Repeindre une chambre',
        description:
            'Je recherche une personne soigneuse pour repeindre une chambre.',
        city: 'Les Abymes',
        postalCode: '97139',
        phone: '0690123456',
        phoneCountryCode: '+590',
        category: 'Bricolage / Travaux',
        subcategory: 'Peinture',
        missionDelay: 'Cette semaine',
        budget: '250',
        hidePhone: true,
      ),
    );

    await pumpPage(tester, store);

    expect(find.text('Saisie manuelle activée · Aide IA facultative'),
        findsOneWidget);
    expect(
      tester.widget<TextField>(titleField()).controller?.text,
      'Repeindre une chambre',
    );
    expect(
      tester.widget<TextField>(descriptionField()).controller?.text,
      contains('personne soigneuse'),
    );
    final mission = tester.widget<PublishOfferMissionFields>(
      find.byType(PublishOfferMissionFields),
    );
    final phone = tester.widget<PublishOfferPhoneFields>(
      find.byType(PublishOfferPhoneFields),
    );
    expect(mission.selectedDelay, 'Cette semaine');
    expect(mission.budgetController.text, '250');
    expect(phone.initialCountryCode, '+590');
    expect(phone.controller.text, '0690123456');
    expect(phone.hidePhone, isTrue);

    await tester.enterText(titleField(), 'Repeindre deux chambres');
    await tester.pump(const Duration(milliseconds: 400));

    final saved = store.draft;
    expect(saved?.title, 'Repeindre deux chambres');
    expect(saved?.description, contains('personne soigneuse'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('la réinitialisation supprime le brouillon durable',
      (tester) async {
    final store = _MemoryPublishOfferDraftStore(
      PublishOfferDraft(
        ownerId: 'user-971',
        savedAt: DateTime.now(),
        title: 'Brouillon à supprimer',
        description:
            'Cette description assez longue doit disparaître avec le reset.',
      ),
    );
    await pumpPage(tester, store);

    await tester.tap(find.byTooltip('Réinitialiser tous les champs'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Réinitialiser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(store.draft, isNull);
    expect(find.text('Remplir sans l’IA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
