import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final offers = firestore.collection(kOffersCollection);

    await offers.doc('active-old').set(<String, dynamic>{
      'status': 'active',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    });
    await offers.doc('active-new').set(<String, dynamic>{
      'status': 'active',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(6000),
    });
    await offers.doc('published').set(<String, dynamic>{
      'status': 'published',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(5000),
    });
    await offers.doc('active-flag').set(<String, dynamic>{
      'isActive': true,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(4000),
    });
    await offers.doc('published-flag').set(<String, dynamic>{
      'isPublished': true,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(3000),
    });
    await offers.doc('visible').set(<String, dynamic>{
      'visibility': 'public',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    });
    await offers.doc('visible-nested').set(<String, dynamic>{
      'visibility': <String, dynamic>{'isPublic': true},
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1500),
    });
  });

  test('executes every standard public-offer query variant', () async {
    final variants = buildPublicOffersQueryVariants(
      firestore: firestore,
      limit: 10,
    );

    expect(variants, hasLength(6));

    final idsByVariant = <Set<String>>[];
    for (final query in variants) {
      idsByVariant.add((await query.get()).docs.map((doc) => doc.id).toSet());
    }

    expect(idsByVariant[0], <String>{'active-old', 'active-new'});
    expect(idsByVariant[1], <String>{'published'});
    expect(idsByVariant[2], <String>{'active-flag'});
    expect(idsByVariant[3], <String>{'published-flag'});
    expect(idsByVariant[4], <String>{'visible'});
    expect(idsByVariant[5], <String>{'visible-nested'});
  });

  test('latest variants order descending and apply their limit', () async {
    final variants = buildLatestPublicOffersQueryVariants(
      firestore: firestore,
      limit: 1,
    );

    expect(variants, hasLength(6));

    final firstIds = <String>[];
    for (final query in variants) {
      final snapshot = await query.get();
      expect(snapshot.docs, hasLength(1));
      firstIds.add(snapshot.docs.single.id);
    }

    expect(
      firstIds,
      <String>[
        'active-new',
        'published',
        'active-flag',
        'published-flag',
        'visible',
        'visible-nested',
      ],
    );
  });

  test('listing variants honor a zero-result limit', () async {
    await firestore.collection(kListingsCollection).doc('listing').set(
      <String, dynamic>{
        'status': 'active',
        'visibility': 'public',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      },
    );

    final standard = buildPublicListingsQueryVariants(
      firestore: firestore,
      limit: 0,
    ).single;
    final latest = buildLatestPublicListingsQueryVariants(
      firestore: firestore,
      limit: 0,
    ).single;

    expect((await standard.get()).docs, isEmpty);
    expect((await latest.get()).docs, isEmpty);
  });
}
