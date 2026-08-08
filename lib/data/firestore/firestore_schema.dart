/// Canonical Firestore collection and field names used by the Flutter client.
///
/// Keep this contract deliberately small and expand it incrementally as each
/// domain is audited. Centralising names prevents silent drift between models,
/// repositories and query/index definitions without changing persisted data.
abstract final class FirestoreCollections {
  static const String listings = 'listings';
}

abstract final class ListingFields {
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
