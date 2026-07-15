import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/favorite_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late List<String> toggledIds;
  late List<({String listingId, bool added})> analyticsEvents;
  late bool toggleResult;
  late FavoriteRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    toggledIds = <String>[];
    analyticsEvents = <({String listingId, bool added})>[];
    toggleResult = true;
    repository = FavoriteRepository(
      firestore: firestore,
      toggleCaller: (listingId) async {
        toggledIds.add(listingId);
        return toggleResult;
      },
      favoriteChangeLogger: ({
        required String listingId,
        required bool added,
      }) async {
        analyticsEvents.add((listingId: listingId, added: added));
      },
    );
  });

  test('retourne des résultats vides pour un utilisateur absent', () async {
    expect(await repository.getFavoriteOfferIds('   '), isEmpty);
    expect(await repository.watchFavoriteOffers(' ').first, isEmpty);
    expect(await repository.watchFavoriteListingIds('').first, isEmpty);

    final result =
        await repository.loadFavoriteListingIdsWithLegacyFallback(' ');
    expect(result.listingIds, isEmpty);
    expect(result.favoriteDates, isEmpty);
    expect(await repository.isFavorite('', 'offer-1'), isFalse);
    expect(await repository.isFavorite('user-1', ' '), isFalse);
    expect(await repository.addFavorite('', 'offer-1'), isFalse);
    expect(await repository.removeFavorite('user-1', ''), isFalse);
  });

  test('charge les favoris canoniques triés et leurs dates', () async {
    final newer = Timestamp.fromMillisecondsSinceEpoch(3000);
    final older = Timestamp.fromMillisecondsSinceEpoch(1000);
    final favorites = firestore
        .collection('users')
        .doc('user-1')
        .collection('favorites');

    await favorites.doc('offer-old').set(<String, dynamic>{
      'offerId': 'offer-old',
      'createdAt': older,
    });
    await favorites.doc('offer-new').set(<String, dynamic>{
      'listingId': 'offer-new',
      'createdAt': newer,
    });
    await favorites.doc('ignored').set(<String, dynamic>{
      'offerId': '   ',
      'listingId': '   ',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(4000),
    });

    expect(
      await repository.getFavoriteOfferIds(' user-1 '),
      <String>['offer-new', 'offer-old'],
    );

    final result =
        await repository.loadFavoriteListingIdsWithLegacyFallback('user-1');
    expect(result.listingIds, <String>['offer-new', 'offer-old']);
    expect(result.favoriteDates, <String, Timestamp?>{
      'offer-new': newer,
      'offer-old': older,
    });
    expect(
      () => result.listingIds.add('forbidden'),
      throwsUnsupportedError,
    );
    expect(
      () => result.favoriteDates['forbidden'] = null,
      throwsUnsupportedError,
    );
  });

  test('observe les favoris canoniques et les convertit en ensemble', () async {
    final favorites = firestore
        .collection('users')
        .doc('user-1')
        .collection('favorites');
    await favorites.doc('offer-1').set(<String, dynamic>{
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    });

    final emissions = await repository
        .watchFavoriteOffers('user-1')
        .take(2)
        .toList();
    expect(emissions, hasLength(2));
    expect(emissions.first.single.offerId, 'offer-1');
    expect(emissions.last.single.offerId, 'offer-1');
    expect(
      await repository.watchFavoriteListingIds('user-1').first,
      <String>{'offer-1'},
    );
  });

  test('utilise les favoris globaux avec déduplication en fallback', () async {
    final global = firestore.collection('favorites');
    await global.doc('global-1').set(<String, dynamic>{
      'userId': 'user-1',
      'listingId': 'offer-global',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    });
    await global.doc('global-duplicate').set(<String, dynamic>{
      'userId': 'user-1',
      'offerId': 'offer-global',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    });
    await global.doc('other-user').set(<String, dynamic>{
      'userId': 'user-2',
      'offerId': 'offer-other',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(4000),
    });

    expect(
      await repository.getFavoriteOfferIds('user-1'),
      <String>['offer-global'],
    );
  });

  test('utilise la sous-collection historique en dernier recours', () async {
    final legacy = firestore
        .collection('users')
        .doc('user-1')
        .collection('favoriteOffers');
    final addedAt = Timestamp.fromMillisecondsSinceEpoch(2000);
    await legacy.doc('offer-legacy').set(<String, dynamic>{
      'addedAt': addedAt,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    });

    final result =
        await repository.loadFavoriteListingIdsWithLegacyFallback('user-1');
    expect(result.listingIds, <String>['offer-legacy']);
    expect(result.favoriteDates['offer-legacy'], addedAt);
  });

  test('détecte un favori dans les trois schémas de stockage', () async {
    await firestore
        .collection('users')
        .doc('user-canonical')
        .collection('favorites')
        .doc('offer-1')
        .set(<String, dynamic>{'createdAt': Timestamp.now()});
    await firestore
        .collection('favorites')
        .doc('user-global__offer-2')
        .set(<String, dynamic>{
      'userId': 'user-global',
      'listingId': 'offer-2',
      'createdAt': Timestamp.now(),
    });
    await firestore
        .collection('users')
        .doc('user-legacy')
        .collection('favoriteOffers')
        .doc('offer-3')
        .set(<String, dynamic>{'createdAt': Timestamp.now()});

    expect(await repository.isFavorite('user-canonical', 'offer-1'), isTrue);
    expect(await repository.isFavorite('user-global', 'offer-2'), isTrue);
    expect(await repository.isFavorite('user-legacy', 'offer-3'), isTrue);
    expect(await repository.isFavorite('user-missing', 'offer-4'), isFalse);
  });

  test('ajoute un nouveau favori via la frontière callable', () async {
    expect(await repository.addFavorite(' user-1 ', ' offer-new '), isTrue);
    expect(toggledIds, <String>['offer-new']);
    expect(
      analyticsEvents,
      <({String listingId, bool added})>[
        (listingId: 'offer-new', added: true),
      ],
    );
  });

  test('ne rappelle pas le backend pour un favori déjà présent', () async {
    await firestore
        .collection('users')
        .doc('user-1')
        .collection('favorites')
        .doc('offer-existing')
        .set(<String, dynamic>{'createdAt': Timestamp.now()});

    expect(
      await repository.addFavorite('user-1', 'offer-existing'),
      isTrue,
    );
    expect(toggledIds, isEmpty);
    expect(analyticsEvents, isEmpty);
  });

  test('supprime un favori canonique sans appel distant résiduel', () async {
    final reference = firestore
        .collection('users')
        .doc('user-1')
        .collection('favorites')
        .doc('offer-1');
    await reference.set(<String, dynamic>{'createdAt': Timestamp.now()});

    expect(await repository.removeFavorite('user-1', 'offer-1'), isFalse);
    expect((await reference.get()).exists, isFalse);
    expect(toggledIds, isEmpty);
  });

  test('désactive un favori historique via le backend', () async {
    await firestore
        .collection('users')
        .doc('user-1')
        .collection('favoriteOffers')
        .doc('offer-legacy')
        .set(<String, dynamic>{'createdAt': Timestamp.now()});
    toggleResult = false;

    expect(
      await repository.removeFavorite('user-1', 'offer-legacy'),
      isTrue,
    );
    expect(toggledIds, <String>['offer-legacy']);
    expect(
      analyticsEvents,
      <({String listingId, bool added})>[
        (listingId: 'offer-legacy', added: false),
      ],
    );
  });

  test('valide et normalise les appels toggleFavorite', () async {
    await expectLater(
      repository.toggleFavorite('   '),
      throwsA(
        isA<FirebaseException>()
            .having((error) => error.code, 'code', 'invalid-argument'),
      ),
    );

    toggleResult = false;
    expect(await repository.toggleFavorite(' offer-9 '), isFalse);
    expect(toggledIds, <String>['offer-9']);
    expect(
      analyticsEvents,
      <({String listingId, bool added})>[
        (listingId: 'offer-9', added: false),
      ],
    );
  });
}
