import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
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
    MarketplaceHumanVerification? verification,
  })  : _listingRepository = listingRepository ?? ListingRepository(),
        _storage = storage ?? FirebaseStorage.instance,
        _verification = verification ?? const MarketplaceHumanVerification();

  final ListingRepository _listingRepository;
  final FirebaseStorage _storage;
  final MarketplaceHumanVerification _verification;

  void _validateDraftInputs({
    required String title,
    required String description,
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();

    if (trimmedTitle.length < 10) {
      throw StateError('Le titre doit contenir au moins 10 caractères.');
    }
    if (trimmedTitle.length > 120) {
      throw StateError('Le titre doit contenir au maximum 120 caractères.');
    }
    if (trimmedDescription.length < 30) {
      throw StateError('La description doit contenir au moins 30 caractères.');
    }
    if (trimmedDescription.length > 4000) {
      throw StateError('La description doit contenir au maximum 4000 caractères.');
    }
  }

  bool _isChannelConnectionError(Object error) {
    if (error is! PlatformException) {
      return false;
    }

    final message = (error.message ?? '').toLowerCase().trim();
    return error.code == 'channel-error' ||
        message.contains('unable to establish connection');
  }

  Future<T> _runWithChannelRetry<T>({
    required String stepLabel,
    required Future<T> Function() action,
    T? fallbackValue,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (!_isChannelConnectionError(error)) rethrow;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));

    try {
      return await action();
    } catch (error) {
      if (!_isChannelConnectionError(error)) rethrow;
      if (fallbackValue != null) {
        return fallbackValue;
      }

      throw StateError(
        'Connexion au service "$stepLabel" impossible. Fermez puis relancez l\'application et réessayez.',
      );
    }
  }

  Future<List<ListingMediaInput>> _uploadPhotos({
    required String uid,
    required List<XFile> photos,
  }) async {
    final media = <ListingMediaInput>[];
    for (var index = 0; index < photos.length; index += 1) {
      final photo = photos[index];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _storageExtension(photo);
      final contentType = _storageContentType(photo);
      final rawPath = 'offers_raw/$uid/${timestamp}_$index.$extension';

      final ref = _storage.ref().child(rawPath);
      final bytes = await photo.readAsBytes();
      await _runWithChannelRetry<void>(
        stepLabel: 'stockage photo',
        action: () => ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        ),
      );

      final downloadUrl = await _runWithChannelRetry<String>(
        stepLabel: 'url photo',
        action: () => ref.getDownloadURL(),
      );

      if (downloadUrl.trim().isEmpty) {
        throw StateError('Le stockage photo n\'a pas renvoyé d\'URL exploitable.');
      }

      media.add(
        ListingMediaInput(
          storagePath: rawPath,
          downloadUrl: downloadUrl,
          thumbnailUrl: downloadUrl,
          mimeType: contentType,
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
    _validateDraftInputs(
      title: title,
      description: description,
    );

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

    final media = photos.isEmpty
      ? const <ListingMediaInput>[]
      : await _uploadPhotos(uid: ownerId, photos: photos);
    final draftId = await _runWithChannelRetry<String>(
      stepLabel: 'brouillon Firestore',
      action: () => _listingRepository.createDraft(
      MarketplaceListingDraft(
        ownerId: ownerId,
        title: title,
        description: description,
        price: price,
        categoryId: categoryId,
        cityId: cityId,
        media: media,
      ),
      ),
    );

    final recaptchaToken = await _runWithChannelRetry<String>(
      stepLabel: 'vérification humaine',
      fallbackValue: '',
      action: () => _verification.obtainToken(
        MarketplaceHumanVerificationAction.listingSubmit,
      ),
    );
    final submission = await _runWithChannelRetry<MarketplacePublishResult?>(
      stepLabel: 'publication finale',
      action: () async {
        final result = await _listingRepository.submitDraft(
          draftId: draftId,
          recaptchaToken: recaptchaToken,
        );
        final displayMedia = result.media.isNotEmpty
            ? result.media
                .map(
                  (entry) => ListingMediaInput(
                    storagePath: (entry['storagePath'] ?? '').toString().trim(),
                    downloadUrl: (entry['downloadUrl'] ?? '').toString().trim(),
                    thumbnailUrl: ((entry['thumbnailUrl'] ?? entry['downloadUrl']) ?? '')
                        .toString()
                        .trim(),
                    width: entry['width'] is num ? (entry['width'] as num).toInt() : null,
                    height: entry['height'] is num ? (entry['height'] as num).toInt() : null,
                    mimeType: (entry['mimeType'] ?? '').toString().trim().isEmpty
                        ? null
                        : (entry['mimeType'] ?? '').toString().trim(),
                    sizeBytes: entry['sizeBytes'] is num
                        ? (entry['sizeBytes'] as num).toInt()
                        : null,
                  ),
                )
                .where((entry) =>
                    entry.storagePath.isNotEmpty && entry.downloadUrl.isNotEmpty)
                .toList(growable: false)
            : media;

        final statusBadges = <String>[
          if (isUrgent) 'Urgent',
          if (result.status.value == 'active') 'En ligne' else 'En revue',
        ];

        return MarketplacePublishResult(
          listingId: result.listingId,
          detailData: <String, dynamic>{
            'id': result.listingId,
            'offerId': result.listingId,
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
            'publishedAtLabel': result.status.value == 'active'
                ? 'Annonce publiée'
                : 'Annonce en revue',
            'availability': (missionDelay ?? '').trim().isEmpty
                ? 'Disponibilité à confirmer'
                : missionDelay!.trim(),
            'missionDelay': (missionDelay ?? '').trim(),
            'averageDelay': (missionDelay ?? '').trim(),
            'statusBadges': statusBadges,
            'imageUrls': displayMedia
                .map((entry) => entry.downloadUrl)
                .toList(growable: false),
            'media': displayMedia
              .map((entry) => entry.toMap())
              .toList(growable: false),
            'ownerId': ownerId,
            'userId': ownerId,
            'status': result.status.value,
            'moderationStatus': result.moderationStatus.value,
            'visibility': result.visibility.value,
            'isMarketplace': true,
          },
        );
      },
    );

    return submission!;
  }

  String _storageExtension(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime == 'image/webp') return 'webp';
    if (mime == 'image/avif') return 'avif';
    if (mime == 'image/png') return 'png';
    if (mime == 'image/heic' || mime == 'image/heif') return 'heic';
    if (mime == 'image/gif') return 'gif';
    if (mime == 'image/bmp') return 'bmp';
    if (mime == 'image/tiff') return 'tiff';
    if (mime == 'image/jpeg' || mime == 'image/jpg') return 'jpg';

    final path = photo.path.toLowerCase();
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.avif')) return 'avif';
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.heic') || path.endsWith('.heif')) return 'heic';
    if (path.endsWith('.gif')) return 'gif';
    if (path.endsWith('.bmp')) return 'bmp';
    if (path.endsWith('.tif') || path.endsWith('.tiff')) return 'tiff';
    if (path.endsWith('.jpeg') || path.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  String _storageContentType(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime.startsWith('image/')) {
      return mime;
    }

    return switch (_storageExtension(photo)) {
      'webp' => 'image/webp',
      'avif' => 'image/avif',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'tiff' => 'image/tiff',
      _ => 'image/jpeg',
    };
  }
}