import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/listing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  late FakeFirebaseFirestore firestore;
  late ListingRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ListingRepository(firestore: firestore);
  });

  Future<void> addListing({
    required String id,
    required int createdAtMs,
    String ownerId = 'owner-a',
    String status = 'active',
    String visibility = 'public',
    String categoryId = 'jardinage',
    String cityId = 'les-abymes-97139',
  }) {
    final createdAt = Timestamp.fromMillisecondsSinceEpoch(createdAtMs);
    return firestore.collection('listings').doc(id).set(<String, dynamic>{
      'ownerId': ownerId,
      'title': 'Annonce $id',
      'description': 'Description complète de l’annonce $id.',
      'price': 45,
      'categoryId': categoryId,
      'cityId': cityId,
      'media': const <Map<String, dynamic>>[],
      'thumbnailUrl': '',
      'status': status,
      'moderationStatus': 'approved',
      'visibility': visibility,
      'createdAt': createdAt,
      'updatedAt': createdAt,
      'publishedAt': createdAt,
      'reportCount': 0,
      'favoriteCount': 0,
      'viewCount': 0,
      'contactCount': 0,
      'isBoosted': false,
      'riskScore': 0,
    });
  }

  test('normalise une clé de cache stable pour la première page', () {
    expect(
      publicListingsFirstPageCacheKey(
        categoryId: ' Jardinage ',
        cityId: ' Les-Abymes-97139 ',
        limit: 500,
      ),
      'jardinage|les-abymes-97139|100',
    );
    expect(
      publicListingsFirstPageCacheKey(limit: 0),
      '||1',
    );
  });

  test('filtre, trie et pagine les annonces publiques', () async {
    await addListing(id: 'ancienne', createdAtMs: 1000);
    await addListing(id: 'recente', createdAtMs: 3000);
    await addListing(id: 'milieu', createdAtMs: 2000);
    await addListing(
      id: 'privee',
      createdAtMs: 4000,
      visibility: 'private',
    );
    await addListing(
      id: 'brouillon',
      createdAtMs: 5000,
      status: 'draft',
    );
    await addListing(
      id: 'autre-categorie',
      createdAtMs: 6000,
      categoryId: 'bricolage',
    );
    await addListing(
      id: 'autre-ville',
      createdAtMs: 7000,
      cityId: 'pointe-a-pitre-97110',
    );

    final firstPage = await repository.fetchPublicListingsPage(
      categoryId: 'jardinage',
      cityId: 'les-abymes-97139',
      limit: 2,
    );

    expect(
      firstPage.items.map((listing) => listing.id),
      <String>['recente', 'milieu'],
    );
    expect(firstPage.hasMore, isTrue);
    expect(firstPage.lastDocument?.id, 'milieu');

    final secondPage = await repository.fetchPublicListingsPage(
      categoryId: 'jardinage',
      cityId: 'les-abymes-97139',
      limit: 2,
      startAfter: firstPage.lastDocument,
    );

    expect(
      secondPage.items.map((listing) => listing.id),
      <String>['ancienne'],
    );
    expect(secondPage.hasMore, isFalse);
    expect(secondPage.lastDocument?.id, 'ancienne');
  });

  test('met en cache la première page puis l invalide explicitement', () async {
    await addListing(id: 'initiale', createdAtMs: 1000);

    await repository.preloadPublicListings(limit: 20);
    await addListing(id: 'nouvelle', createdAtMs: 2000);

    final cached = await repository.fetchPublicListings(limit: 20);
    expect(
      cached.map((listing) => listing.id),
      <String>['initiale'],
    );

    repository.invalidatePublicListingsCache();
    final refreshed = await repository.fetchPublicListings(limit: 20);
    expect(
      refreshed.map((listing) => listing.id),
      <String>['nouvelle', 'initiale'],
    );
  });

  test('diffuse les annonces publiques et les annonces du propriétaire',
      () async {
    await addListing(id: 'owner-a-ancienne', createdAtMs: 1000);
    await addListing(id: 'owner-a-recente', createdAtMs: 3000);
    await addListing(
      id: 'owner-b',
      createdAtMs: 2000,
      ownerId: 'owner-b',
    );
    await addListing(
      id: 'owner-a-privee',
      createdAtMs: 4000,
      visibility: 'private',
    );

    final publicItems = await repository.watchPublicListings(limit: 10).first;
    expect(
      publicItems.map((listing) => listing.id),
      <String>['owner-a-recente', 'owner-b', 'owner-a-ancienne'],
    );

    final ownerItems = await repository.watchMyListings('owner-a').first;
    expect(
      ownerItems.map((listing) => listing.id),
      <String>['owner-a-privee', 'owner-a-recente', 'owner-a-ancienne'],
    );
  });

  test('retourne une page vide avec un curseur nul', () async {
    final page = await repository.fetchPublicListingsPage(limit: 50);

    expect(page.items, isEmpty);
    expect(page.lastDocument, isNull);
    expect(page.hasMore, isFalse);
  });
}
