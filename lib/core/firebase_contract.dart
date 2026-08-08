class FirestoreCollections {
  static const users = 'users';
  static const listings = 'listings';
  static const listingDrafts = 'listingDrafts';
  static const conversations = 'conversations';
  static const messages = 'messages';
  static const favorites = 'favorites';
  static const listingReports = 'listingReports';
  static const notifications = 'notifications';

  // Legacy read-only only
  static const legacyOffers = 'offers';
  static const legacyProfiles = 'profiles';
  static const legacyListingDrafts = 'listing_drafts';
}

class ListingFields {
  static const String ownerId = 'ownerId';
  static const String title = 'title';
  static const String description = 'description';
  static const String price = 'price';
  static const String categoryId = 'categoryId';
  static const String cityId = 'cityId';
  static const String media = 'media';
  static const String thumbnailUrl = 'thumbnailUrl';
  static const String status = 'status';
  static const String moderationStatus = 'moderationStatus';
  static const String visibility = 'visibility';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String publishedAt = 'publishedAt';
  static const String expiresAt = 'expiresAt';
  static const String reportCount = 'reportCount';
  static const String favoriteCount = 'favoriteCount';
  static const String viewCount = 'viewCount';
  static const String contactCount = 'contactCount';
  static const String isBoosted = 'isBoosted';
  static const String boostExpiresAt = 'boostExpiresAt';
  static const String riskScore = 'riskScore';
}

class StoragePaths {
  static String listingDraftRaw({
    required String uid,
    required String draftId,
    required String fileName,
  }) =>
      'listingDrafts/$uid/$draftId/$fileName';

  static String listingFinal({
    required String uid,
    required String listingId,
    required String fileName,
  }) =>
      'listings/$uid/$listingId/$fileName';
}
