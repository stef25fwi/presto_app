import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/publish_offer_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 9, 23, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sauvegarde et recharge tous les champs du même compte', () async {
    final store = PublishOfferDraftStore(now: () => now);
    final draft = PublishOfferDraft(
      ownerId: 'user-971',
      savedAt: now,
      title: 'Repeindre une chambre',
      description: 'Je recherche une personne soigneuse pour les travaux.',
      city: 'Les Abymes',
      postalCode: '97139',
      phone: '0690123456',
      phoneCountryCode: '+590',
      category: 'Bricolage / Travaux',
      subcategory: 'Peinture',
      missionDelay: 'Cette semaine',
      budgetType: 'Fixe',
      budget: '250',
      hidePhone: true,
    );

    await store.save(draft);
    final restored = await store.loadForOwner('user-971');

    expect(restored, isNotNull);
    expect(restored!.title, draft.title);
    expect(restored.description, draft.description);
    expect(restored.city, 'Les Abymes');
    expect(restored.postalCode, '97139');
    expect(restored.phone, '0690123456');
    expect(restored.phoneCountryCode, '+590');
    expect(restored.category, 'Bricolage / Travaux');
    expect(restored.subcategory, 'Peinture');
    expect(restored.missionDelay, 'Cette semaine');
    expect(restored.budget, '250');
    expect(restored.hidePhone, isTrue);
  });

  test('un changement de compte purge le brouillon du compte précédent',
      () async {
    final store = PublishOfferDraftStore(now: () => now);
    await store.save(
      PublishOfferDraft(
        ownerId: 'user-a',
        savedAt: now,
        title: 'Brouillon A',
      ),
    );
    await store.save(
      PublishOfferDraft(
        ownerId: 'user-b',
        savedAt: now,
        title: 'Brouillon B',
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    final draftKeys = preferences
        .getKeys()
        .where((key) => key.startsWith('publish_offer_draft.v1.'))
        .toList();
    expect(draftKeys, hasLength(1));
    expect((await store.loadForOwner('user-b'))?.title, 'Brouillon B');
  });

  test('supprime les données expirées, futures ou illisibles', () async {
    final store = PublishOfferDraftStore(now: () => now);
    await store.save(
      PublishOfferDraft(
        ownerId: 'expired-user',
        savedAt: now.subtract(const Duration(days: 8)),
        title: 'Trop ancien',
      ),
    );
    expect(await store.loadForOwner('expired-user'), isNull);

    await store.save(
      PublishOfferDraft(
        ownerId: 'future-user',
        savedAt: now.add(const Duration(minutes: 1)),
        title: 'Horodatage futur',
      ),
    );
    expect(await store.loadForOwner('future-user'), isNull);

    await store.save(
      PublishOfferDraft(
        ownerId: 'broken-user',
        savedAt: now,
        title: 'Valide avant corruption',
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    final key = preferences
        .getKeys()
        .singleWhere((entry) => entry.startsWith('publish_offer_draft.v1.'));
    await preferences.setString(key, jsonEncode(<String, Object>{
      'version': PublishOfferDraft.schemaVersion,
      'ownerId': 'another-user',
      'savedAt': now.toIso8601String(),
    }));
    expect(await store.loadForOwner('broken-user'), isNull);
    expect(preferences.containsKey(key), isFalse);
  });

  test('un brouillon vide et la purge explicite ne laissent aucune donnée',
      () async {
    final store = PublishOfferDraftStore(now: () => now);
    await store.save(
      PublishOfferDraft(
        ownerId: 'user-1',
        savedAt: now,
        title: 'À effacer',
      ),
    );
    await store.save(
      PublishOfferDraft(ownerId: 'user-1', savedAt: now),
    );
    expect(await store.loadForOwner('user-1'), isNull);

    await store.save(
      PublishOfferDraft(
        ownerId: 'user-2',
        savedAt: now,
        title: 'Autre brouillon',
      ),
    );
    await store.clearAll();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences
          .getKeys()
          .where((key) => key.startsWith('publish_offer_draft.v1.')),
      isEmpty,
    );
  });
}
