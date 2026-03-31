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
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (mimeType != null && mimeType!.trim().isNotEmpty) 'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
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
  final String? phone;
  final String? budgetType;
  final String? missionDelay;
  final bool isUrgent;
  final String? subCategory;
  final String? category;
  final String? city;
  final String? location;
  final String? postalCode;
  final String? cp;
  final String? dept;
  final String? region;
  final String? cityCategoryKey;
  final double? budgetValue;

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
    this.phone,
    this.budgetType,
    this.missionDelay,
    this.isUrgent = false,
    this.subCategory,
    this.category,
    this.city,
    this.location,
    this.postalCode,
    this.cp,
    this.dept,
    this.region,
    this.cityCategoryKey,
    this.budgetValue,
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
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      if (budgetType != null && budgetType!.trim().isNotEmpty) 'budgetType': budgetType!.trim(),
      if (missionDelay != null && missionDelay!.trim().isNotEmpty) 'missionDelay': missionDelay!.trim(),
      'isUrgent': isUrgent,
      if (subCategory != null && subCategory!.trim().isNotEmpty) 'subCategory': subCategory!.trim(),
      if (category != null && category!.trim().isNotEmpty) 'category': category!.trim(),
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (location != null && location!.trim().isNotEmpty) 'location': location!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty) 'postalCode': postalCode!.trim(),
      if (cp != null && cp!.trim().isNotEmpty) 'cp': cp!.trim(),
      if (dept != null && dept!.trim().isNotEmpty) 'dept': dept!.trim(),
      if (region != null && region!.trim().isNotEmpty) 'region': region!.trim(),
      if (cityCategoryKey != null && cityCategoryKey!.trim().isNotEmpty)
        'cityCategoryKey': cityCategoryKey!.trim(),
      if (budgetValue != null) 'budgetValue': budgetValue,
    };
  }
}