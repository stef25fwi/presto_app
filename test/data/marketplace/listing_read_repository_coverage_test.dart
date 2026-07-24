import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/listing_read_repository.dart';

Future<void> _seedListing(
  FakeFirebaseFirestore firestore, {
  required String id,
  required int createdAtMs,
  String status = 'active',
  String visibility = 'public',
  String categoryId = 'jardinage',
  String cityId = '97122_baie-mahault',
}) {
  final timestamp = Timestamp.fromMillisecondsSinceEpoch(createdAtMs);
  return firestore.collection('listings').doc(id).set(<String, dynamic>{
    'ownerId': 'owner-1',
    'ownerName': 'Alice',
    'title': ' Annonce $id ',
    'description': ' Description de $id ',
    'price': 45,
    'categoryId': categoryId,
    'cityId': cityId,
    'cityCategoryKey': '${cityId}_$categoryId',
    'city': 'Baie-Mahault',
    'postalCode': '97122',
    'status': status,
    'visibility': visibility,
    'moderationStatus': 'approved',
    'createdAt': timestamp,
    'publishedAt': timestamp,
    'media': <Map<String, dynamic>>[
      <String, dynamic>{
        'downloadUrl': 'https://cdn.test/$id.webp',
        'thumbnailUrl': 'https://cdn.test/${id}_thumb.webp',
      },
    ],
  });
}

Iterable<String> _ids(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  return docs.map((doc) => doc.id);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ListingReadRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = ListingReadRepository(firestore: firestore);
    await _seedListing(firestore, id: 'recent', createdAtMs: 3000);
    await _seedListing(firestore, id: 'older', createdAtMs: 1000);
    await _seedListing(
      firestore,
      id: 'other-city',
      createdAtMs: 2000,
      cityId: '97110_pointe-a-pitre',
    );
    await _seedListing(
      firestore,
      id: 'private',
      createdAtMs: 5000,
      visibility: 'private',
    );
    await _seedListing(
      firestore,
      id: 'draft',
      createdAtMs: 6000,
      status: 'draft',
    );
  });

  test('lit un snapshot en normalisant l identifiant', () async {
    final snapshot = await repository.getListingSnapshot(' recent ');

    expect(snapshot.exists, isTrue);
    expect(snapshot.id, 'recent');
    expect(snapshot.data()?['title'], ' Annonce recent ');
  });

  test('retourne les données existantes et null pour un document absent', () async {
    final data = await repository.getListingData('older');

    expect(data?['categoryId'], 'jardinage');
    expect(await repository.getListingData('missing'), isNull);
  });

  test('filtre strictement les annonces actives et publiques', () async {
    expect(
      (await repository.getPublicListingData('recent'))?['title'],
      ' Annonce recent ',
    );
    expect(await repository.getPublicListingData('private'), isNull);
    expect(await repository.getPublicListingData('draft'), isNull);
    expect(await repository.getPublicListingData('missing'), isNull);
  });

  test('mappe une annonce publique vers le modèle UI', () async {
    final data = await repository.getPublicOfferUiData('recent');

    expect(data, isNotNull);
    expect(data?['id'], 'recent');
    expect(data?['offerId'], 'recent');
    expect(data?['listingId'], 'recent');
    expect(data?['title'], 'Annonce recent');
    expect(data?['pseudo'], 'Alice');
    expect(data?['imageUrls'], <String>['https://cdn.test/recent.webp']);
    expect(data?['isMarketplace'], isTrue);
    expect(await repository.getPublicOfferUiData('private'), isNull);
  });

  test('construit les requêtes latest et browse avec filtres', () async {
    final latest = repository.buildLatestPublicQueries(limit: 2);
    expect(latest, hasLength(1));
    expect(
      _ids((await latest.single.get()).docs),
      <String>['recent', 'other-city'],
    );

    final browse = repository.buildBrowseQueries(
      limit: 10,
      latestFirst: false,
      categoryId: ' jardinage ',
      cityId: ' 97122_baie-mahault ',
    );
    expect(browse, hasLength(1));
    expect(
      _ids((await browse.single.get()).docs),
      unorderedEquals(<String>['recent', 'older']),
    );
  });

  test('charge et fusionne les documents latest publics', () async {
    final docs = await repository.loadLatestPublicListingDocs(
      limit: 10,
      source: 'listing-read-latest-test',
    );

    expect(_ids(docs), <String>['recent', 'other-city', 'older']);
  });

  test('charge les documents browse filtrés', () async {
    final docs = await repository.loadBrowsePublicListingDocs(
      limit: 10,
      latestFirst: true,
      categoryId: 'jardinage',
      cityId: '97122_baie-mahault',
      source: 'listing-read-browse-test',
    );

    expect(_ids(docs), <String>['recent', 'older']);
  });

  test('expose la requête publique de base', () async {
    final snapshot = await repository.publicListingsBaseQuery().get();

    expect(
      _ids(snapshot.docs),
      unorderedEquals(<String>['recent', 'older', 'other-city']),
    );
  });
}
