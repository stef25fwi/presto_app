import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/favorite_repository.dart';

void main() {
  group('FavoriteRepository Firestore fallbacks', () {
    test('charge les favoris canoniques avec createdAt et ignore un id vide',
        () async {
      final firestore = FakeFirebaseFirestore();
      final createdAt = Timestamp.fromDate(DateTime.utc(2026, 7, 1));
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('favorites')
          .doc('canonical')
          .set(<String, dynamic>{
        'offerId': 'listing-1',
        'createdAt': createdAt,
      });
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('favorites')
          .doc('ignored')
          .set(<String, dynamic>{'offerId': ''});

      final repository = FavoriteRepository(firestore: firestore);
      final result =
          await repository.loadFavoriteListingIdsWithLegacyFallback('user-1');

      expect(result.listingIds, <String>['listing-1']);
      expect(result.favoriteDates['listing-1'], createdAt);
    });

    test('utilise le favori global puis le legacy avec addedAt', () async {
      final firestore = FakeFirebaseFirestore();
      final addedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 2));
      await firestore.collection('favorites').doc('global').set(<String, dynamic>{
        'userId': 'user-global',
        'listingId': 'listing-global',
        'createdAt': addedAt,
      });
      await firestore
          .collection('users')
          .doc('user-legacy')
          .collection('favoriteOffers')
          .doc('listing-legacy')
          .set(<String, dynamic>{
        'offerId': 'listing-legacy',
        'addedAt': addedAt,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(0),
      });

      final repository = FavoriteRepository(firestore: firestore);

      expect(
        await repository.getFavoriteOfferIds('user-global'),
        <String>['listing-global'],
      );
      expect(
        await repository.getFavoriteOfferIds('user-legacy'),
        <String>['listing-legacy'],
      );
    });

    test('détecte les favoris globaux et legacy quand le canonique est absent',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('favorites')
          .doc('user-global__listing-global')
          .set(<String, dynamic>{'active': true});
      await firestore
          .collection('users')
          .doc('user-legacy')
          .collection('favoriteOffers')
          .doc('listing-legacy')
          .set(<String, dynamic>{'active': true});

      final repository = FavoriteRepository(firestore: firestore);

      expect(
        await repository.isFavorite('user-global', 'listing-global'),
        isTrue,
      );
      expect(
        await repository.isFavorite('user-legacy', 'listing-legacy'),
        isTrue,
      );
    });

    test('supprime le document canonique sans appeler le toggle devenu inutile',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('favorites')
          .doc('listing-1')
          .set(<String, dynamic>{'offerId': 'listing-1'});
      var toggleCalls = 0;
      final repository = FavoriteRepository(
        firestore: firestore,
        toggleCaller: (_) async {
          toggleCalls += 1;
          return false;
        },
        favoriteChangeLogger: ({required listingId, required added}) async {},
      );

      final removed = await repository.removeFavorite('user-1', 'listing-1');

      expect(removed, isFalse);
      expect(toggleCalls, 0);
      expect(
        (await firestore
                .collection('users')
                .doc('user-1')
                .collection('favorites')
                .doc('listing-1')
                .get())
            .exists,
        isFalse,
      );
    });
  });
}
