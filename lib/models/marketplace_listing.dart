import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/firestore/firestore_schema.dart';
import '../services/firestore_date_parser.dart';
import 'marketplace_enums.dart';

class MarketplaceListing {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final double price;
  final String categoryId;
  final String cityId;
  final List<Map<String, dynamic>> media;
  final String thumbnailUrl;
  final ListingStatus status;
  final ModerationStatus moderationStatus;
  final ListingVisibility visibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final int reportCount;
  final int favoriteCount;
  final int viewCount;
  final int contactCount;
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final int riskScore;

  const MarketplaceListing({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.cityId,
    required this.media,
    required this.thumbnailUrl,
    required this.status,
    required this.moderationStatus,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.expiresAt,
    required this.reportCount,
    required this.favoriteCount,
    required this.viewCount,
    required this.contactCount,
    required this.isBoosted,
    required this.boostExpiresAt,
    required this.riskScore,
  });

  factory MarketplaceListing.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return MarketplaceListing.fromMap(snapshot.id, data);
  }

  factory MarketplaceListing.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return MarketplaceListing(
      id: id,
      ownerId: (data[ListingFields.ownerId] ?? '').toString().trim(),
      title: (data[ListingFields.title] ?? '').toString().trim(),
      description: (data[ListingFields.description] ?? '').toString().trim(),
      price: (data[ListingFields.price] is num)
          ? (data[ListingFields.price] as num).toDouble()
          : 0,
      categoryId: (data[ListingFields.categoryId] ?? '').toString().trim(),
      cityId: (data[ListingFields.cityId] ?? '').toString().trim(),
      media: ((data[ListingFields.media] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) =>
              Map<String, dynamic>.from(entry.cast<String, dynamic>()))
          .toList(growable: false),
      thumbnailUrl:
          (data[ListingFields.thumbnailUrl] ?? '').toString().trim(),
      status: ListingStatusParsing.fromString(
        (data[ListingFields.status] ?? '').toString(),
      ),
      moderationStatus: ModerationStatusParsing.fromString(
        (data[ListingFields.moderationStatus] ?? '').toString(),
      ),
      visibility: ListingVisibilityParsing.fromString(
        (data[ListingFields.visibility] ?? '').toString(),
      ),
      createdAt: parseFirestoreDateTime(data[ListingFields.createdAt]),
      updatedAt: parseFirestoreDateTime(data[ListingFields.updatedAt]),
      publishedAt: parseFirestoreDateTime(data[ListingFields.publishedAt]),
      expiresAt: parseFirestoreDateTime(data[ListingFields.expiresAt]),
      reportCount: (data[ListingFields.reportCount] is num)
          ? (data[ListingFields.reportCount] as num).toInt()
          : 0,
      favoriteCount: (data[ListingFields.favoriteCount] is num)
          ? (data[ListingFields.favoriteCount] as num).toInt()
          : 0,
      viewCount: (data[ListingFields.viewCount] is num)
          ? (data[ListingFields.viewCount] as num).toInt()
          : 0,
      contactCount: (data[ListingFields.contactCount] is num)
          ? (data[ListingFields.contactCount] as num).toInt()
          : 0,
      isBoosted: data[ListingFields.isBoosted] == true,
      boostExpiresAt:
          parseFirestoreDateTime(data[ListingFields.boostExpiresAt]),
      riskScore: (data[ListingFields.riskScore] is num)
          ? (data[ListingFields.riskScore] as num).toInt()
          : 0,
    );
  }

  bool get isPubliclyVisible {
    return status == ListingStatus.active &&
        visibility == ListingVisibility.public;
  }
}

class ListingSubmissionResult {
  final String listingId;
  final ListingStatus status;
  final ModerationStatus moderationStatus;
  final ListingVisibility visibility;
  final int riskScore;
  final String thumbnailUrl;
  final List<Map<String, dynamic>> media;

  const ListingSubmissionResult({
    required this.listingId,
    required this.status,
    required this.moderationStatus,
    required this.visibility,
    required this.riskScore,
    required this.thumbnailUrl,
    required this.media,
  });

  factory ListingSubmissionResult.fromMap(Map<String, dynamic> data) {
    return ListingSubmissionResult(
      listingId: (data['listingId'] ?? '').toString().trim(),
      status:
          ListingStatusParsing.fromString((data['status'] ?? '').toString()),
      moderationStatus: ModerationStatusParsing.fromString(
        (data['moderationStatus'] ?? '').toString(),
      ),
      visibility: ListingVisibilityParsing.fromString(
          (data['visibility'] ?? '').toString()),
      riskScore:
          (data['riskScore'] is num) ? (data['riskScore'] as num).toInt() : 0,
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString().trim(),
      media: ((data['media'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((entry) =>
              Map<String, dynamic>.from(entry.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
