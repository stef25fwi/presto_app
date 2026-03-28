import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_listing.dart';
import 'package:presto_app/models/marketplace_listing_draft.dart';

void main() {
  test('MarketplaceListingDraft serializes expected fields', () {
    const draft = MarketplaceListingDraft(
      ownerId: 'user_1',
      title: 'Peinture salon 25m2',
      description: 'Recherche artisan serieux pour peinture complete.',
      price: 320,
      categoryId: 'painting',
      cityId: 'paris',
      media: <ListingMediaInput>[
        ListingMediaInput(
          storagePath: 'listingDrafts/user_1/draft_1/photo.jpg',
          downloadUrl: 'https://example.test/photo.jpg',
          thumbnailUrl: 'https://example.test/photo_thumb.jpg',
        ),
      ],
    );

    final data = draft.toFirestore();
    expect(data['ownerId'], 'user_1');
    expect(data['status'], 'draft');
    expect((data['media'] as List).length, 1);
  });

  test('MarketplaceListing parses firestore payload', () {
    final listing = MarketplaceListing.fromMap(
      'listing_1',
      <String, dynamic>{
        'ownerId': 'owner_1',
        'title': 'Annonce test',
        'description': 'Description test complete pour annonce.',
        'price': 42,
        'categoryId': 'cat_1',
        'cityId': 'city_1',
        'media': <Map<String, dynamic>>[],
        'thumbnailUrl': 'https://example.test/thumb.jpg',
        'status': 'active',
        'moderationStatus': 'approved',
        'visibility': 'public',
        'reportCount': 2,
        'favoriteCount': 5,
        'viewCount': 20,
        'contactCount': 3,
        'isBoosted': true,
        'riskScore': 7,
      },
    );

    expect(listing.status, ListingStatus.active);
    expect(listing.moderationStatus, ModerationStatus.approved);
    expect(listing.isPubliclyVisible, isTrue);
    expect(listing.favoriteCount, 5);
  });
}