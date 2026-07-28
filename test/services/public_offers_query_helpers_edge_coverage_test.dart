import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection(kListingsCollection).doc('a').set(
      <String, dynamic>{
        'status': 'active',
        'visibility': 'public',
        'categoryId': 'cat-a',
        'cityId': 'city-a',
        'cityCategoryKey': 'city-a_cat-a',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
      },
    );
    await firestore.collection(kListingsCollection).doc('b').set(
      <String, dynamic>{
        'status': 'active',
        'visibility': 'public',
        'categoryId': 'cat-b',
        'cityId': 'city-b',
        'cityCategoryKey': 'city-b_cat-b',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      },
    );
    await firestore.collection(kOffersCollection).doc('owner-offer').set(
      <String, dynamic>{
        'ownerId': 'owner-a',
        'status': 'published',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      },
    );
  });

  test('whitespace-only filters keep the canonical unfiltered query', () async {
    final query = buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      categoryId: '   ',
      cityId: '\t',
      latestFirst: false,
      limit: 10,
    ).single;

    final snapshot = await query.get();
    expect(snapshot.docs.map((doc) => doc.id), unorderedEquals(<String>['a', 'b']));
  });

  test('latest marketplace query respects a strict result limit', () async {
    final query = buildMarketplaceListingsBrowseQueries(
      firestore: firestore,
      latestFirst: true,
      limit: 1,
    ).single;

    final snapshot = await query.get();
    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.single.id, 'a');
  });

  test('owner variants return no document for an unknown owner', () async {
    final variants = buildLegacyPublicOffersByOwnerQueryVariants(
      firestore: firestore,
      ownerField: 'ownerId',
      ownerId: 'missing-owner',
      limit: 5,
    );

    expect(variants, hasLength(6));
    for (final query in variants) {
      expect((await query.get()).docs, isEmpty);
    }
  });

  test('merging empty query results remains deterministic', () async {
    final merged = await loadMergedPublicOfferQueryVariants(
      queries: <Query<Map<String, dynamic>>>[
        firestore.collection(kOffersCollection).where(
              'ownerId',
              isEqualTo: 'missing-owner',
            ),
      ],
      source: 'edge-empty-merge',
    );

    expect(merged, isEmpty);
  });
}
