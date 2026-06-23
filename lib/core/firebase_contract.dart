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
