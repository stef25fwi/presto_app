import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/marketplace/listing_read_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ListingReadRepository repository;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = ListingReadRepository(firestore: firestore);

    final listings = firestore.collection('listings');
    await listings.doc('public-old').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'public',
      'title': 'Ancienne annonce publique',
      'description': 'Description ancienne',
      'city': 'Sainte-Anne',
      'postalCode': '97180',
      'price': 60,
      'ownerId': 'owner-old',
      'ownerName': 'Ancien annonceur',
      'categoryId': 'jardinage',
      'cityId': 'sainte-anne',
      'cityCategoryKey': 'sainte-anne_jardinage',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      'imageUrls': <String>['https://example.test/old.jpg'],
    });
    await listings.doc('public-new').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'public',
      'title': 'Nouvelle annonce publique',
      'description': 'Description récente',
      'city': 'Sainte-Anne',
      'postalCode': '97180',
      'price': 90,
      'ownerId': 'owner-new',
      'ownerName': 'Nouvel annonceur',
      'categoryId': 'jardinage',
      'cityId': 'sainte-anne',
      'cityCategoryKey': 'sainte-anne_jardinage',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 7, 1)),
      'media': <Map<String, dynamic>>[
        <String, dynamic>{
          'downloadUrl': 'https://example.test/new.jpg',
        },
      ],
    });
    await listings.doc('private').set(<String, dynamic>{
      'status': 'active',
      'visibility': 'private',
      'title': 'Annonce privée',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 1)),
    });
    await listings.doc('inactive').set(<String, dynamic>{
      'status': 'draft',
      'visibility': 'public',
      'title': 'Brouillon public',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 1)),
    });
  });

  test('lit les snapshots, données publiques et mapping UI', () async {
    final snapshot = await repository.getListingSnapshot('  public-new  ');
    expect(snapshot.exists, isTrue);
    expect(snapshot.id, 'public-new');

    final data = await repository.getListingData('public-new');
    expect(data?['title'], 'Nouvelle annonce publique');
    expect(await repository.getListingData('missing'), isNull);

    expect(await repository.getPublicListingData('private'), isNull);
    expect(await repository.getPublicListingData('inactive'), isNull);
    expect(
      (await repository.getPublicListingData('public-new'))?['ownerId'],
      'owner-new',
    );

    expect(await repository.getPublicOfferUiData('missing'), isNull);
    final ui = await repository.getPublicOfferUiData('public-new');
    expect(ui?['id'], 'public-new');
    expect(ui?['offerId'], 'public-new');
    expect(ui?['title'], 'Nouvelle annonce publique');
    expect(ui?['thumbnailUrl'], 'https://example.test/new.jpg');
    expect(ui?['isMarketplace'], isTrue);
  });

  test('construit et exécute les variantes latest, browse et base', () async {
    final latestQueries = repository.buildLatestPublicQueries(limit: 1);
    expect(latestQueries, hasLength(1));
    final latestSnapshot = await latestQueries.single.get();
    expect(latestSnapshot.docs, hasLength(1));
    expect(latestSnapshot.docs.single.id, 'public-new');

    final browseQueries = repository.buildBrowseQueries(
      limit: 5,
      latestFirst: false,
      categoryId: ' jardinage ',
      cityId: ' sainte-anne ',
    );
    expect(browseQueries, hasLength(1));
    final browseSnapshot = await browseQueries.single.get();
    expect(
      browseSnapshot.docs.map((doc) => doc.id),
      containsAll(<String>['public-old', 'public-new']),
    );

    final latestDocs = await repository.loadLatestPublicListingDocs(
      limit: 2,
      source: 'listing-read-coverage-latest',
    );
    expect(latestDocs.map((doc) => doc.id), <String>['public-new', 'public-old']);

    final browseDocs = await repository.loadBrowsePublicListingDocs(
      limit: 5,
      latestFirst: true,
      categoryId: 'jardinage',
      cityId: 'sainte-anne',
      source: 'listing-read-coverage-browse',
    );
    expect(
      browseDocs.map((doc) => doc.id),
      <String>['public-new', 'public-old'],
    );

    final baseSnapshot = await repository.publicListingsBaseQuery().get();
    expect(
      baseSnapshot.docs.map((doc) => doc.id).toSet(),
      <String>{'public-old', 'public-new'},
    );
  });
}
