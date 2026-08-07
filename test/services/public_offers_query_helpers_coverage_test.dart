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

  test('ensureAppCheckReadyForPublicFirestoreRead est sans effet hors web', () async {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;

    await ensureAppCheckReadyForPublicFirestoreRead(source: 'coverage-test');

    expect(appCheckActivationAttempted, isTrue);
    expect(appCheckActivationSucceeded, isFalse);
    expect(appCheckActivationError, isNull);
  });
}
