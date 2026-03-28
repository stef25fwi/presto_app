import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../data/marketplace/listing_repository.dart';
import '../models/marketplace_enums.dart';
import '../models/marketplace_listing_draft.dart';
import 'city_search.dart';
import 'marketplace_human_verification.dart';
import 'offer_indexing.dart';

class MarketplacePublishResult {
  final String listingId;
  final Map<String, dynamic> detailData;

  const MarketplacePublishResult({
    required this.listingId,
    required this.detailData,
  });
}

class MarketplacePublishService {
  MarketplacePublishService({
    ListingRepository? listingRepository,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    MarketplaceHumanVerification? verification,
  })  : _listingRepository = listingRepository ?? ListingRepository(),
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1'),
        _verification = verification ?? const MarketplaceHumanVerification();

  final ListingRepository _listingRepository;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final MarketplaceHumanVerification _verification;

  Future<List<ListingMediaInput>> _uploadPhotos({
    required String uid,
    required List<XFile> photos,
  }) async {
    final callable = _functions.httpsCallable(
      'processOfferPhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final media = <ListingMediaInput>[];
    for (var index = 0; index < photos.length; index += 1) {
      final photo = photos[index];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _storageExtension(photo);
      final contentType = _storageContentType(photo);
      final rawPath = 'offers_raw/$uid/${timestamp}_$index.$extension';

      final ref = _storage.ref().child(rawPath);
      final bytes = await photo.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final response = await callable.call<dynamic>(<String, dynamic>{
        'storagePath': rawPath,
      });
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final storagePath = (data['storagePath'] ?? '').toString().trim();
      final downloadUrl = (data['downloadUrl'] ?? '').toString().trim();
      if (storagePath.isEmpty || downloadUrl.isEmpty) {
        throw StateError('Le traitement d\'image marketplace a renvoyé un payload incomplet.');
      }

      media.add(
        ListingMediaInput(
          storagePath: storagePath,
          downloadUrl: downloadUrl,
          thumbnailUrl: downloadUrl,
          mimeType: 'image/webp',
          sizeBytes: bytes.length,
        ),
      );
    }

    return media;
  }

  Future<MarketplacePublishResult> publish({
    required String ownerId,
    required String title,
    required String description,
    required String category,
    required String city,
    required String postalCode,
    required String phone,
    required String? subCategory,
    required String? missionDelay,
    required bool isUrgent,
    required double price,
    required String budgetType,
    required List<XFile> photos,
  }) async {
    if (photos.isEmpty) {
      throw StateError('Ajoutez au moins une photo avant de publier cette annonce marketplace.');
    }

    final resolvedCategory = canonicalizeOfferCategory(category) ?? 'Autre';
    final trimmedCity = city.trim();
    var resolvedPostalCode = postalCode.trim();
    if (trimmedCity.isEmpty) {
      throw StateError('La ville est obligatoire pour publier une annonce marketplace.');
    }
    if (resolvedPostalCode.isEmpty) {
      final cityMatch = CitySearch.instance.search(trimmedCity, limit: 1);
      if (cityMatch.isNotEmpty) {
        resolvedPostalCode = cityMatch.first.cp.trim();
      }
    }

    final indexed = buildOfferIndexFields(
      category: resolvedCategory,
      city: trimmedCity,
      postalCode: resolvedPostalCode,
      budget: price,
      status: 'active',
      isActive: true,
    );
    final categoryId = (indexed['categoryId'] ?? '').toString().trim();
    final cityId = (indexed['cityId'] ?? '').toString().trim();
    if (categoryId.isEmpty || cityId.isEmpty) {
      throw StateError('Impossible de résoudre la catégorie ou la ville pour Marketplace.');
    }

    final media = await _uploadPhotos(uid: ownerId, photos: photos);
    final draftId = await _listingRepository.createDraft(
      MarketplaceListingDraft(
        ownerId: ownerId,
        title: title,
        description: description,
        price: price,
        categoryId: categoryId,
        cityId: cityId,
        media: media,
      ),
    );

    final recaptchaToken = await _verification.obtainToken(
      MarketplaceHumanVerificationAction.listingSubmit,
    );
    final submission = await _listingRepository.submitDraft(
      draftId: draftId,
      recaptchaToken: recaptchaToken,
    );

    final statusBadges = <String>[
      if (isUrgent) 'Urgent',
      if (submission.status.value == 'active') 'En ligne' else 'En revue',
    ];

    return MarketplacePublishResult(
      listingId: submission.listingId,
      detailData: <String, dynamic>{
        'id': submission.listingId,
        'offerId': submission.listingId,
        'title': title.trim(),
        'shortDescription': (subCategory ?? '').trim(),
        'detail': (subCategory ?? '').trim(),
        'city': trimmedCity,
        'location': trimmedCity,
        'postalCode': resolvedPostalCode,
        'cp': resolvedPostalCode,
        'category': resolvedCategory,
        'categoryId': categoryId,
        'cityId': cityId,
        'description': description.trim(),
        'phone': phone.trim(),
        'price': price,
        'budget': price,
        'budgetType': budgetType,
        'isUrgent': isUrgent,
        'publishedAtLabel': submission.status.value == 'active'
            ? 'Annonce publiée'
            : 'Annonce en revue',
        'availability': (missionDelay ?? '').trim().isEmpty
            ? 'Disponibilité à confirmer'
            : missionDelay!.trim(),
        'missionDelay': (missionDelay ?? '').trim(),
        'averageDelay': (missionDelay ?? '').trim(),
        'statusBadges': statusBadges,
        'imageUrls': media
            .map((entry) => entry.downloadUrl)
            .toList(growable: false),
        'media': media.map((entry) => entry.toMap()).toList(growable: false),
        'ownerId': ownerId,
        'userId': ownerId,
        'status': submission.status.value,
        'moderationStatus': submission.moderationStatus.value,
        'visibility': submission.visibility.value,
        'isMarketplace': true,
      },
    );
  }

  String _storageExtension(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime == 'image/webp') return 'webp';
    if (mime == 'image/png') return 'png';
    if (mime == 'image/heic' || mime == 'image/heif') return 'heic';
    if (mime == 'image/gif') return 'gif';

    final path = photo.path.toLowerCase();
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.heic') || path.endsWith('.heif')) return 'heic';
    if (path.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  String _storageContentType(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime.startsWith('image/')) {
      return mime;
    }

    return switch (_storageExtension(photo)) {
      'webp' => 'image/webp',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}