import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
  });

  test('pickPublicListingsBrowseFilterField normalise les filtres', () {
    expect(
      pickPublicListingsBrowseFilterField(),
      PublicListingsBrowseFilterField.none,
    );
    expect(
      pickPublicListingsBrowseFilterField(categoryId: '  '),
      PublicListingsBrowseFilterField.none,
    );
    expect(
      pickPublicListingsBrowseFilterField(categoryId: 'plomberie'),
      PublicListingsBrowseFilterField.categoryId,
    );
    expect(
      pickPublicListingsBrowseFilterField(cityId: '97101'),
      PublicListingsBrowseFilterField.cityId,
    );
    expect(
      pickPublicListingsBrowseFilterField(
        categoryId: ' plomberie ',
        cityId: ' 97101 ',
      ),
      PublicListingsBrowseFilterField.cityCategoryKey,
    );
  });

  test('legacy public offers backfill reste desactive', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(kOffersCollection).doc('legacy').set(
      <String, dynamic>{'status': 'active'},
    );

    final docs = await loadLegacyPublicOffersBackfill(
      query: firestore.collection(kOffersCollection),
      source: 'coverage-test',
    );

    expect(docs, isEmpty);
  });

  test('publicOffersAppCheckStateLabel couvre les trois etats', () {
    expect(publicOffersAppCheckStateLabel(), 'not-attempted');

    appCheckActivationAttempted = true;
    expect(publicOffersAppCheckStateLabel(), 'failed');

    appCheckActivationSucceeded = true;
    expect(publicOffersAppCheckStateLabel(), 'ok');
  });

  test('buildPublicListingsQueryVariants ne retourne que les annonces publiques actives', () async {
    final firestore = FakeFirebaseFirestore();
    final listings = firestore.collection(kListingsCollection);
    await listings.doc('public-active').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'public',
      'createdAt': DateTime.utc(2026, 8, 3),
    });
    await listings.doc('private-active').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'private',
      'createdAt': DateTime.utc(2026, 8, 4),
    });
    await listings.doc('public-draft').set(<String, dynamic>{
      'status': 'draft',
      'visibility': 'public',
      'createdAt': DateTime.utc(2026, 8, 5),
    });

    final variants = buildPublicListingsQueryVariants(
      firestore: firestore,
      limit: 10,
    );
    expect(variants, hasLength(1));

    final snapshot = await variants.single.get();
    expect(snapshot.docs.map((doc) => doc.id), <String>['public-active']);
  });

  test('buildPublicListingsQueryVariants applique la limite', () async {
    final firestore = FakeFirebaseFirestore();
    final listings = firestore.collection(kListingsCollection);
    for (var i = 0; i < 4; i++) {
      await listings.doc('listing-$i').set(<String, dynamic>{
        'status': 'active',
        'visibility': 'public',
        'createdAt': DateTime.utc(2026, 8, i + 1),
      });
    }

    final snapshot = await buildPublicListingsQueryVariants(
      firestore: firestore,
      limit: 2,
    ).single.get();

    expect(snapshot.docs, hasLength(2));
  });

  test('buildLatestPublicListingsQueryVariants trie par createdAt decroissant', () async {
    final firestore = FakeFirebaseFirestore();
    final listings = firestore.collection(kListingsCollection);
    await listings.doc('older').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'public',
      'createdAt': DateTime.utc(2026, 8, 1),
    });
    await listings.doc('newest').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'public',
      'createdAt': DateTime.utc(2026, 8, 7),
    });
    await listings.doc('middle').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'public',
      'createdAt': DateTime.utc(2026, 8, 4),
    });
    await listings.doc('ignored-private').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'private',
      'createdAt': DateTime.utc(2026, 8, 8),
    });

    final variants = buildLatestPublicListingsQueryVariants(
      firestore: firestore,
      limit: 2,
    );
    expect(variants, hasLength(1));

    final snapshot = await variants.single.get();
    expect(
      snapshot.docs.map((doc) => doc.id),
      <String>['newest', 'middle'],
    );
  });

  test('marketplace browse couvre filtre ville categorie combinaison et pagination', () async {
    final firestore = FakeFirebaseFirestore();
    final listings = firestore.collection(kListingsCollection);
    for (final entry in <(String, String, String, DateTime)>[
      ('older', '97105', 'plomberie', DateTime.utc(2026, 8, 1)),
      ('newer', '97105', 'plomberie', DateTime.utc(2026, 8, 3)),
      ('other', '97101', 'plomberie', DateTime.utc(2026, 8, 4)),
    ]) {
      await listings.doc(entry.$1).set(<String, dynamic>{
        'status': 'active',
        'visibility': 'public',
        'cityId': entry.$2,
        'categoryId': entry.$3,
        'cityCategoryKey': '${entry.$2}_${entry.$3}',
        'createdAt': entry.$4,
      });
    }

    final byCity = await buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      latestFirst: false,
      cityId: ' 97105 ',
    ).single.get();
    expect(byCity.docs.map((doc) => doc.id).toSet(), <String>{'older', 'newer'});

    final byCategory = await buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      latestFirst: false,
      categoryId: ' plomberie ',
    ).single.get();
    expect(byCategory.docs, hasLength(3));

    final combined = await buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      latestFirst: true,
      cityId: ' 97105 ',
      categoryId: ' plomberie ',
    ).single.get();
    expect(combined.docs.map((doc) => doc.id), <String>['newer', 'older']);

    final firstPage = await buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      latestFirst: true,
      limit: 1,
    ).single.get();
    expect(firstPage.docs.single.id, 'other');

    final secondPage = await buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      latestFirst: true,
      limit: 2,
      startAfterDocument: firstPage.docs.single,
    ).single.get();
    expect(secondPage.docs.map((doc) => doc.id), <String>['newer', 'older']);
  });

  test('legacy offer variants couvrent les six schemas et le tri newest-first', () async {
    final firestore = FakeFirebaseFirestore();
    final offers = firestore.collection(kOffersCollection);
    await offers.doc('active').set(<String, dynamic>{
      'status': 'active',
      'createdAt': DateTime.utc(2026, 8, 1),
    });
    await offers.doc('published').set(<String, dynamic>{
      'status': 'published',
      'createdAt': DateTime.utc(2026, 8, 2),
    });
    await offers.doc('is-active').set(<String, dynamic>{
      'isActive': true,
      'createdAt': DateTime.utc(2026, 8, 3),
    });
    await offers.doc('is-published').set(<String, dynamic>{
      'isPublished': true,
      'createdAt': DateTime.utc(2026, 8, 4),
    });
    await offers.doc('visibility').set(<String, dynamic>{
      'visibility': 'public',
      'createdAt': DateTime.utc(2026, 8, 5),
    });
    await offers.doc('nested').set(<String, dynamic>{
      'visibility': <String, dynamic>{'isPublic': true},
      'createdAt': DateTime.utc(2026, 8, 6),
    });

    final variants = buildPublicOffersQueryVariants(
      firestore: firestore,
      limit: 10,
    );
    expect(variants, hasLength(6));
    final ids = <String>{};
    for (final query in variants) {
      ids.addAll((await query.get()).docs.map((doc) => doc.id));
    }
    expect(
      ids,
      <String>{
        'active',
        'published',
        'is-active',
        'is-published',
        'visibility',
        'nested',
      },
    );

    final latest = buildLatestPublicOffersQueryVariants(
      firestore: firestore,
      limit: 10,
    );
    expect(latest, hasLength(6));
    for (final query in latest) {
      expect((await query.get()).docs, hasLength(1));
    }
  });

  test('merged loader deduplique les resultats de variantes qui se chevauchent', () async {
    final firestore = FakeFirebaseFirestore();
    final offers = firestore.collection(kOffersCollection);
    await offers.doc('active-only').set(<String, dynamic>{'status': 'active'});
    await offers.doc('is-active-only').set(<String, dynamic>{'isActive': true});
    await offers.doc('shared').set(<String, dynamic>{
      'status': 'active',
      'isActive': true,
    });

    final queries = <Query<Map<String, dynamic>>>[
      offers.where('status', isEqualTo: 'active'),
      offers.where('isActive', isEqualTo: true),
    ];
    final merged = await loadMergedPublicOfferQueryVariants(
      queries: queries,
      source: 'coverage-test',
    );

    expect(
      merged.map((doc) => doc.id).toSet(),
      <String>{'active-only', 'is-active-only', 'shared'},
    );
    expect(merged.where((doc) => doc.id == 'shared'), hasLength(1));
  });

  test('mergeOfferDocsById conserve une seule occurrence par id', () async {
    final firestore = FakeFirebaseFirestore();
    final offers = firestore.collection(kOffersCollection);
    await offers.doc('primary').set(<String, dynamic>{'group': 'a'});
    await offers.doc('shared').set(<String, dynamic>{'group': 'both'});
    await offers.doc('secondary').set(<String, dynamic>{'group': 'b'});

    final primary = await offers.where('group', whereIn: <String>['a', 'both']).get();
    final secondary = await offers.where('group', whereIn: <String>['b', 'both']).get();
    final merged = mergeOfferDocsById(primary.docs, secondary.docs);

    expect(
      merged.map((doc) => doc.id).toSet(),
      <String>{'primary', 'shared', 'secondary'},
    );
    expect(merged.where((doc) => doc.id == 'shared'), hasLength(1));
  });

  test('ensureAppCheckReadyForPublicFirestoreRead est sans effet hors web', () async {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;

    await ensureAppCheckReadyForPublicFirestoreRead(source: 'coverage-test');

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckActivationError, isNull);
  });
}
