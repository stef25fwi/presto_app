import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> mapMarketplaceListingToOfferUi({
  required String listingId,
  required Map<String, dynamic> data,
}) {
  final media = ((data['media'] as List?) ?? const <dynamic>[])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry.cast<String, dynamic>()))
      .toList(growable: false);
  final mediaUrls = media
      .map((entry) =>
          ((entry['downloadUrl'] ?? entry['thumbnailUrl']) ?? '').toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final imageUrls = ((data['imageUrls'] as List?) ?? const <dynamic>[])
      .map((entry) => entry.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final effectiveImages = imageUrls.isNotEmpty ? imageUrls : mediaUrls;
  final ownerId = (data['ownerId'] ?? data['userId'] ?? '').toString().trim();
  final ownerName = (data['ownerName'] ??
          data['displayName'] ??
          data['pseudo'] ??
          data['userName'] ??
          'Annonceur ilipresto')
      .toString()
      .trim();
  final publishedAt = data['publishedAt'];

  return <String, dynamic>{
    ...data,
    'id': listingId,
    'offerId': listingId,
    'listingId': listingId,
    'title': (data['title'] ?? 'Sans titre').toString().trim(),
    'description': (data['description'] ?? '').toString().trim(),
    'shortDescription': (data['shortDescription'] ?? data['subcategory'] ?? '')
        .toString()
        .trim(),
    'detail': (data['detail'] ?? data['subcategory'] ?? '').toString().trim(),
    'city': (data['city'] ?? data['location'] ?? '').toString().trim(),
    'location': (data['location'] ?? data['city'] ?? '').toString().trim(),
    'postalCode': (data['postalCode'] ?? data['cp'] ?? '').toString().trim(),
    'cp': (data['cp'] ?? data['postalCode'] ?? '').toString().trim(),
    'price': data['price'] ?? data['budget'] ?? data['budgetValue'] ?? 0,
    'budget': data['budget'] ?? data['price'] ?? data['budgetValue'] ?? 0,
    'budgetValue': data['budgetValue'] ?? data['price'] ?? data['budget'] ?? 0,
    'imageUrls': effectiveImages,
    'media': media,
    'thumbnailUrl': (data['thumbnailUrl'] ??
            (effectiveImages.isNotEmpty ? effectiveImages.first : ''))
        .toString()
        .trim(),
    'pseudo': ownerName.isEmpty ? 'Annonceur ilipresto' : ownerName,
    'displayName': ownerName.isEmpty ? 'Annonceur ilipresto' : ownerName,
    'userName': ownerName.isEmpty ? 'Annonceur ilipresto' : ownerName,
    'ownerName': ownerName.isEmpty ? 'Annonceur ilipresto' : ownerName,
    'ownerId': ownerId,
    'userId': ownerId,
    'publishedAtLabel': publishedAt is Timestamp ? 'Annonce publiee' : 'Annonce',
    'isMarketplace': true,
    'advertiser': <String, dynamic>{
      'id': ownerId,
      'name': ownerName.isEmpty ? 'Annonceur ilipresto' : ownerName,
      'verified': data['ownerVerified'] == true,
      'avatarUrl': (data['ownerAvatarUrl'] ?? '').toString().trim(),
    },
  };
}

bool isPublicActiveListingData(Map<String, dynamic> data) {
  return (data['status'] ?? '').toString().trim() == 'active' &&
      (data['visibility'] ?? '').toString().trim() == 'public';
}
