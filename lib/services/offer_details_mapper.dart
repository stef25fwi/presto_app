import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/offers/offer_details_page.dart';

String _offerDetailsPublishedLabel(dynamic raw) {
  if (raw is Timestamp) {
    final publishedAt = raw.toDate();
    final diff = DateTime.now().difference(publishedAt);

    if (diff.inMinutes < 1) return 'Publiee a l\'instant';
    if (diff.inHours < 1) return 'Publiee il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Publiee il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Publiee il y a ${diff.inDays} j';
  }

  return 'Publication recente';
}

String _extractOfferImageUrl(dynamic entry) {
  if (entry == null) return '';
  if (entry is Map) {
    for (final key in const [
      'downloadUrl',
      'thumbnailUrl',
      'imageUrl',
      'photoUrl',
      'url',
      'secureUrl',
      'src',
      'storagePath',
      'filePath',
      'path',
    ]) {
      final value = (entry[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
  return entry.toString().trim();
}

List<String> _collectOfferImageUrls({
  dynamic rawImageUrls,
  dynamic rawMedia,
  dynamic rawImageUrl,
  dynamic rawThumbnailUrl,
}) {
  final orderedUrls = <String>[];

  void addUrl(dynamic value) {
    final url = _extractOfferImageUrl(value);
    if (url.isEmpty || orderedUrls.contains(url)) return;
    orderedUrls.add(url);
  }

  if (rawImageUrls is List) {
    for (final entry in rawImageUrls) {
      addUrl(entry);
    }
  }
  if (rawMedia is List) {
    for (final entry in rawMedia) {
      addUrl(entry);
    }
  }
  addUrl(rawImageUrl);
  addUrl(rawThumbnailUrl);
  return orderedUrls;
}

Offer buildOfferDetailsOffer({
  required String offerId,
  required Map<String, dynamic> data,
}) {
  final title = (data['title'] ?? '').toString().trim();
  final location = ((data['location'] ?? data['city']) ?? '').toString().trim();
  final postalCode = ((data['postalCode'] ?? data['cp']) ?? '').toString().trim();
  final category = (data['category'] ?? '').toString().trim();
  final description = (data['description'] ?? '').toString().trim();
  final isUrgent =
      (data['isUrgent'] as bool?) ?? (data['urgent'] as bool?) ?? false;
  final budget = data['budget'];
  final price = budget is num ? budget.toDouble() : 0.0;
  final rawMedia = (data['media'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry.cast<dynamic, dynamic>()))
      .toList(growable: false);
  final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString().trim();
  final imageUrls = _collectOfferImageUrls(
    rawImageUrls: data['imageUrls'],
    rawMedia: rawMedia,
    rawImageUrl: data['imageUrl'],
    rawThumbnailUrl: thumbnailUrl,
  );
  final advertiserName =
      ((data['userName'] ?? data['pseudo']) ?? '').toString().trim();
  final serviceArea =
      (data['serviceArea'] ?? (location.isEmpty ? 'Zone locale' : location))
          .toString();
  final missionDelay =
      ((data['missionDelay'] ?? data['averageDelay']) ?? 'Délai non précisé')
          .toString();
  final createdAt = data['createdAt'];
  final publishedAt = data['publishedAt'];
  final listingStatus = (data['status'] ?? '').toString().trim();
  final moderationStatus = (data['moderationStatus'] ?? '').toString().trim();
  final visibility = (data['visibility'] ?? '').toString().trim();
  final mediaProcessingStatus =
      (data['mediaProcessingStatus'] ?? '').toString().trim();
  final categoryId = (data['categoryId'] ?? '').toString().trim();
  final cityId = (data['cityId'] ?? '').toString().trim();
  final isMarketplaceValue = data['isMarketplace'];
  final inferredMarketplace = categoryId.isNotEmpty ||
      cityId.isNotEmpty ||
      listingStatus.isNotEmpty ||
      visibility.isNotEmpty ||
      mediaProcessingStatus.isNotEmpty ||
      data.containsKey('favoriteCount') ||
      data.containsKey('ownerId');
  final isMarketplace = isMarketplaceValue is bool
      ? isMarketplaceValue
      : isMarketplaceValue.toString().trim().toLowerCase() == 'true' ||
          inferredMarketplace;

  return Offer(
    id: offerId,
    listingId: offerId,
    title: title.isEmpty ? 'Annonce' : title,
    price: price,
    category: category.isEmpty ? 'Categorie non precisee' : category,
    categoryId: categoryId,
    city: location.isEmpty ? 'Lieu non precise' : location,
    cityId: cityId,
    postalCode: postalCode,
    isUrgent: isUrgent,
    publishedAtLabel: _offerDetailsPublishedLabel(data['createdAt']),
    publishedAt: publishedAt is Timestamp ? publishedAt.toDate() : null,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    availability:
        (data['availability'] ?? 'Disponibilite a confirmer').toString(),
    shortDescription: description.isEmpty
        ? 'Consultez le detail de cette annonce et contactez l\'annonceur.'
        : description,
    description: description,
    phone: (data['phone'] ?? '').toString(),
    imageUrls: imageUrls,
    media: rawMedia,
    thumbnailUrl: thumbnailUrl,
    statusBadges: <String>[
      'Disponible',
      if (isUrgent) 'Urgent',
      if ((data['verified'] as bool?) ?? false) 'Verifie',
      'Nouveau',
    ],
    status: listingStatus,
    moderationStatus: moderationStatus,
    visibility: visibility,
    mediaProcessingStatus: mediaProcessingStatus,
    isMarketplace: isMarketplace,
    practicalInfo: PracticalInfo(
      category: category.isEmpty ? 'Service' : category,
      serviceArea: serviceArea,
      canTravel: (data['canTravel'] as bool?) ?? true,
      schedule: (data['schedule'] ?? 'Horaires a convenir').toString(),
      missionDelay: missionDelay,
      averageDelay: missionDelay,
      paymentMethod: (data['paymentMethod'] ?? 'Paiement a convenir').toString(),
      serviceType: (data['serviceType'] ?? 'Prestation ponctuelle').toString(),
    ),
    advertiser: Advertiser(
      id: (data['userId'] ?? data['uid'] ?? '').toString(),
      name: advertiserName.isEmpty ? 'Annonceur Presto' : advertiserName,
      verified: (data['verified'] as bool?) ?? false,
      rating:
          (data['rating'] is num) ? (data['rating'] as num).toDouble() : null,
      offersCount: (data['offersCount'] is num)
          ? (data['offersCount'] as num).toInt()
          : 1,
      reviewsCount: (data['reviewsCount'] is num)
          ? (data['reviewsCount'] as num).toInt()
          : (data['reviewCount'] is num)
              ? (data['reviewCount'] as num).toInt()
              : (data['ratingCount'] is num)
                  ? (data['ratingCount'] as num).toInt()
                  : 0,
      seniorityLabel: (data['seniorityLabel'] ?? 'Membre Presto').toString(),
      city: location.isEmpty ? 'Ville non precisee' : location,
      bio: (data['bio'] ?? '').toString(),
      avatarUrl: ((data['avatarUrl'] ??
                  data['photoUrl'] ??
                  data['photoURL'] ??
                  data['profilePhotoUrl'] ??
                  data['imageUrl']) ??
              '')
          .toString(),
      isOnline: ((data['status'] ?? '').toString().toLowerCase() == 'online'),
      lastSeenLabel: 'Activite recente',
    ),
    actionType: ((data['actionType'] ?? '') == 'booking')
        ? OfferActionType.booking
        : OfferActionType.contact,
    similarOffers: const [],
  );
}
