import 'marketplace_enums.dart';

class ListingMediaInput {
  final String storagePath;
  final String downloadUrl;
  final String thumbnailUrl;
  final int? width;
  final int? height;
  final String? mimeType;
  final int? sizeBytes;

  const ListingMediaInput({
    required this.storagePath,
    required this.downloadUrl,
    required this.thumbnailUrl,
    this.width,
    this.height,
    this.mimeType,
    this.sizeBytes,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'width': width,
      'height': height,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }
}

class MarketplaceListingDraft {
  final String? id;
  final String ownerId;
  final String title;
  final String description;
  final double price;
  final String categoryId;
  final String cityId;
  final List<ListingMediaInput> media;
  final ListingStatus status;

  const MarketplaceListingDraft({
    this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.cityId,
    required this.media,
    this.status = ListingStatus.draft,
  });

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'title': title.trim(),
      'description': description.trim(),
      'price': price,
      'categoryId': categoryId.trim(),
      'cityId': cityId.trim(),
      'media': media.map((entry) => entry.toMap()).toList(growable: false),
      'status': status.value,
    };
  }
}