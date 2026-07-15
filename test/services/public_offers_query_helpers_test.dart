import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

Future<void> _seedListings(FakeFirebaseFirestore firestore) async {
  final listings = firestore.collection(kListingsCollection);
  await listings.doc('listing-a').set(<String, dynamic>{
    'status': 'active',
    'visibility': 'public',
    'categoryId': 'cat-a',
    'cityId': 'city-a',
    'cityCategoryKey': 'city-a_cat-a',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(3000),
  });
  await listings.doc('listing-b').set(<String, dynamic>{
    'status': 'active',
    'visibility': 'public',
    'categoryId': 'cat-a',
    'cityId': 'city-b',
    'cityCategoryKey': 'city-b_cat-a',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
  });
  await listings.doc('listing-private').set(<String, dynamic>{
    'status': 'active',
    'visibility': 'private',
    'categoryId': 'cat-a',
    'cityId': 'city-a',
    'cityCategoryKey': 'city-a_cat-a',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(4000),
  });
  await listings.doc('listing-inactive').set(<String, dynamic>{
    'status': 'inactive',
    'visibility': 'public',
    'categoryId': 'cat-a',
    'cityId': 'city-a',
    'cityCategoryKey': 'city-a_cat-a',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(5000),
  });
}

Future<void> _seedLegacyOffers(FakeFirebaseFirestore firestore) async {
  final offers = firestore.collection(kOffersCollection);
  final entries = <String, Map<String, dynamic>>{
    'offer-active': <String, dynamic>{'status': 'active'},
    'offer-published': <String, dynamic>{'status': 'published'},
    'offer-active-flag': <String, dynamic>{'isActive': true},
    'offer-published-flag': <String, dynamic>{'isPublished': true},
    'offer-visible': <String, dynamic>{'visibility': 'public'},
    'offer-visible-nested': <String, dynamic>{
      'visibility': <String, dynamic>{'isPublic': true},
    },
  };

  var timestamp = 1000;
  for (final entry in entries.entries) {
    await offers.doc(entry.key).set(<String, dynamic>{
      ...entry.value,
      'ownerId': 'owner-a',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(timestamp),
    });
    timestamp += 1000;
  }
}

Iterable<String> _ids(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
  return documents.map((document) => document.id);
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
    await _seedListings(firestore);
    await _seedLegacyOffers(firestore);
  });

  test('sélectionne le filtre de navigation canonique', () {
    expect(
      pickPublicListingsBrowseFilterField(),
      PublicListingsBrowseFilterField.none,
    );
    expect(
      pickPublicListingsBrowseFilterField(categoryId: ' cat-a '),
      PublicListingsBrowseFilterField.categoryId,
    );
    expect(
      pickPublicListingsBrowseFilterField(cityId: ' city-a '),
      PublicListingsBrowseFilterField.cityId,
    );
    expect(
      pickPublicListingsBrowseFilterField(
        categoryId: ' cat-a ',
        cityId: ' city-a ',
      ),
      PublicListingsBrowseFilterField.cityCategoryKey,
    );
    expect(publicListingsFilter(), isA<Filter>());
    expect(publicOffersFilter(), isA<Filter>());
  });

  test('expose les trois états App Check', () {
    expect(publicOffersAppCheckStateLabel(), 'not-attempted');
    appCheckActivationAttempted = true;
    expect(publicOffersAppCheckStateLabel(), 'failed');
    appCheckActivationSucceeded = true;
    expect(publicOffersAppCheckStateLabel(), 'ok');
  });

  test('construit et exécute les variantes listings publiques', () async {
    final standard = buildPublicListingsQueryVariants(
      firestore: firestore,
      limit: 10,
    );
    expect(standard, hasLength(1));
    expect(
      _ids((await standard.single.get()).docs),
      unorderedEquals(<String>['listing-a', 'listing-b']),
    );

    final latest = buildLatestPublicListingsQueryVariants(
      firestore: firestore,
      limit: 10,
    );
    final latestDocs = (await latest.single.get()).docs;
    expect(_ids(latestDocs), <String>['listing-a', 'listing-b']);
  });

  test('applique les filtres marketplace et la pagination', () async {
    Future<List<String>> load({
      String? categoryId,
      String? cityId,
      bool latestFirst = true,
      DocumentSnapshot<Map<String, dynamic>>? startAfter,
      int limit = 10,
    }) async {
      final query = buildMarketplaceListingsBrowseQueries(
        firestore: firestore,
        categoryId: categoryId,
        cityId: cityId,
        latestFirst: latestFirst,
        startAfterDocument: startAfter,
        limit: limit,
      ).single;
      return _ids((await query.get()).docs).toList();
    }

    expect(
      await load(latestFirst: false),
      unorderedEquals(<String>['listing-a', 'listing-b']),
    );
    expect(
      await load(categoryId: ' cat-a '),
      <String>['listing-a', 'listing-b'],
    );
    expect(await load(cityId: ' city-a '), <String>['listing-a']);
    expect(
      await load(categoryId: ' cat-a ', cityId: ' city-a '),
      <String>['listing-a'],
    );

    final firstPageQuery = buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      limit: 1,
    ).single;
    final firstPage = await firstPageQuery.get();
    expect(_ids(firstPage.docs), <String>['listing-a']);
    expect(
      await load(startAfter: firstPage.docs.single),
      <String>['listing-b'],
    );
  });

  test('construit et fusionne les variantes des offres legacy', () async {
    final standard = buildPublicOffersQueryVariants(
      firestore: firestore,
      limit: 20,
    );
    final latest = buildLatestPublicOffersQueryVariants(
      firestore: firestore,
      limit: 20,
    );
    expect(standard, hasLength(6));
    expect(latest, hasLength(6));

    final merged = await loadMergedPublicOfferQueryVariants(
      queries: <Query<Map<String, dynamic>>>[...standard, ...latest],
      source: 'legacy-merge-test',
    );
    expect(
      _ids(merged),
      unorderedEquals(<String>[
        'offer-active',
        'offer-published',
        'offer-active-flag',
        'offer-published-flag',
        'offer-visible',
        'offer-visible-nested',
      ]),
    );
  });

  test('fusionne les documents sans écraser la source primaire', () async {
    final active = await firestore
        .collection(kOffersCollection)
        .where('status', isEqualTo: 'active')
        .get();
    final owner = await firestore
        .collection(kOffersCollection)
        .where('ownerId', isEqualTo: 'owner-a')
        .get();
    final merged = mergeOfferDocsById(active.docs, owner.docs);
    expect(merged, hasLength(6));
    expect(merged.first.id, 'offer-active');
  });

  test('désactive explicitement le backfill legacy automatique', () async {
    final result = await loadLegacyPublicOffersBackfill(
      query: firestore.collection(kOffersCollection),
      source: 'disabled-backfill-test',
    );
    expect(result, isEmpty);
  });

  test('charge les offres publiques par propriétaire', () async {
    final variants = buildLegacyPublicOffersByOwnerQueryVariants(
      firestore: firestore,
      ownerField: 'ownerId',
      ownerId: 'owner-a',
      limit: 20,
    );
    expect(variants, hasLength(6));

    final documents = await loadLegacyPublicOffersByOwner(
      firestore: firestore,
      ownerField: 'ownerId',
      ownerId: 'owner-a',
      limit: 20,
      source: 'owner-test',
    );
    expect(documents, hasLength(6));
  });

  test('la préparation App Check est neutre hors Web', () async {
    await expectLater(
      ensureAppCheckReadyForPublicFirestoreRead(source: 'vm-test'),
      completes,
    );
  });
}
