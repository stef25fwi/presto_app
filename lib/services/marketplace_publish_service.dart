import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/validation_constants.dart';
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

  String _resolveOwnerDisplayName(String ownerId, {User? currentUser}) {
    final user = currentUser ?? FirebaseAuth.instance.currentUser;
    if (user?.uid.trim() == ownerId.trim()) {
      final displayName = user?.displayName?.trim() ?? '';
      if (displayName.isNotEmpty) {
        return displayName;
      }

      final emailPrefix = (user?.email ?? '').trim().split('@').first.trim();
      if (emailPrefix.isNotEmpty) {
        return emailPrefix;
      }
    }

    return 'Annonceur iliprestō';
  }

  void _validateDraftInputs({
    required String title,
    required String description,
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();

    if (trimmedTitle.length < ListingValidation.titleMinLength) {
      throw StateError('Le titre doit contenir au moins ${ListingValidation.titleMinLength} caractères.');
    }
    if (trimmedTitle.length > ListingValidation.titleMaxLength) {
      throw StateError('Le titre doit contenir au maximum ${ListingValidation.titleMaxLength} caractères.');
    }
    if (trimmedDescription.length < ListingValidation.descriptionMinLength) {
      throw StateError('La description doit contenir au moins ${ListingValidation.descriptionMinLength} caractères.');
    }
    if (trimmedDescription.length > ListingValidation.descriptionMaxLength) {
      throw StateError(
          'La description doit contenir au maximum ${ListingValidation.descriptionMaxLength} caractères.');
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
        throw StateError(
            'Le stockage photo n\'a pas renvoyé d\'URL exploitable.');
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

  CityRecord? _resolveCanonicalCity({
    required String city,
    required String postalCode,
  }) {
    final rawCity = city.trim();
    final rawPostalCode = postalCode.trim();

    if (rawPostalCode.isNotEmpty) {
      final exactPostal =
          CitySearch.instance.pickBestForPostalCode(rawPostalCode);
      if (exactPostal != null) {
        if (rawCity.isEmpty ||
            normalizeOfferText(exactPostal.name) ==
                normalizeOfferText(rawCity)) {
          return exactPostal;
        }

        final cityMatches = CitySearch.instance.search(rawCity, limit: 10);
        for (final candidate in cityMatches) {
          if (candidate.cp == rawPostalCode) {
            return candidate;
          }
        }
      }
    }

    if (rawCity.isEmpty) return null;
    final candidates = CitySearch.instance.search(rawCity, limit: 10);
    if (candidates.isEmpty) return null;

    if (rawPostalCode.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate.cp == rawPostalCode) {
          return candidate;
        }
      }
    }

    return candidates.first;
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
    final inputCity = city.trim();
    var resolvedPostalCode = postalCode.trim();
    if (inputCity.isEmpty) {
      throw StateError(
          'La ville est obligatoire pour publier une annonce marketplace.');
    }

    final canonicalCity = _resolveCanonicalCity(
      city: inputCity,
      postalCode: resolvedPostalCode,
    );
    if (canonicalCity == null) {
      throw StateError('Choisissez une ville valide dans la liste proposée.');
    }

    final resolvedCity = canonicalCity.name.trim();
    resolvedPostalCode = canonicalCity.cp.trim();

    final indexed = buildOfferIndexFields(
      category: resolvedCategory,
      city: resolvedCity,
      postalCode: resolvedPostalCode,
      budget: price,
      status: 'active',
      isActive: true,
    );
    final categoryId = (indexed['categoryId'] ?? '').toString().trim();
    final cityId = (indexed['cityId'] ?? '').toString().trim();
    if (categoryId.isEmpty || cityId.isEmpty) {
      throw StateError(
          'Impossible de résoudre la catégorie ou la ville pour Marketplace.');
    }

    // 1. Créer le draft SANS media d'abord (évite les orphelins Storage si le draft échoue)
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
          media: const [], // vide pour l'instant
          phone: phone,
          budgetType: budgetType,
          missionDelay: missionDelay,
          isUrgent: isUrgent,
          subCategory: subCategory,
          category: resolvedCategory,
          city: resolvedCity,
          location: resolvedCity,
          postalCode: resolvedPostalCode,
          cp: resolvedPostalCode,
          dept: canonicalCity.dept,
          region: canonicalCity.region,
          cityCategoryKey: (indexed['cityCategoryKey'] ?? '').toString().trim(),
          budgetValue: price,
        ),
      ),
    );

    // 2. Upload les photos en référençant le draftId
    final media = photos.isEmpty
        ? const <ListingMediaInput>[]
        : await _uploadPhotos(uid: ownerId, photos: photos);

    // 3. Mettre à jour le draft avec les media si nécessaire
    if (media.isNotEmpty) {
      await _runWithChannelRetry<void>(
        stepLabel: 'mise à jour media draft',
        action: () => _listingRepository.updateDraftMedia(
          draftId: draftId,
          media: media,
        ),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
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
        final isPublishingSoon = result.status.value != 'active' &&
            result.moderationStatus.value == 'approved';
        final ownerDisplayName = _resolveOwnerDisplayName(ownerId, currentUser: currentUser);
        final displayMedia = result.media.isNotEmpty
            ? result.media
                .map(
                  (entry) => ListingMediaInput(
                    storagePath: (entry['storagePath'] ?? '').toString().trim(),
                    downloadUrl: (entry['downloadUrl'] ?? '').toString().trim(),
                    thumbnailUrl:
                        ((entry['thumbnailUrl'] ?? entry['downloadUrl']) ?? '')
                            .toString()
                            .trim(),
                    width: entry['width'] is num
                        ? (entry['width'] as num).toInt()
                        : null,
                    height: entry['height'] is num
                        ? (entry['height'] as num).toInt()
                        : null,
                    mimeType:
                        (entry['mimeType'] ?? '').toString().trim().isEmpty
                            ? null
                            : (entry['mimeType'] ?? '').toString().trim(),
                    sizeBytes: entry['sizeBytes'] is num
                        ? (entry['sizeBytes'] as num).toInt()
                        : null,
                  ),
                )
                .where((entry) =>
                    entry.storagePath.isNotEmpty &&
                    entry.downloadUrl.isNotEmpty)
                .toList(growable: false)
            : media;

        final statusBadges = <String>[
          if (isUrgent) 'Urgent',
          if (result.status.value == 'active')
            'En ligne'
          else if (isPublishingSoon)
            'Publication imminente'
          else
            'En revue',
        ];

        return MarketplacePublishResult(
          listingId: result.listingId,
          detailData: <String, dynamic>{
            'id': result.listingId,
            'offerId': result.listingId,
            'title': title.trim(),
            'shortDescription': (subCategory ?? '').trim(),
            'detail': (subCategory ?? '').trim(),
            'city': resolvedCity,
            'location': resolvedCity,
            'postalCode': resolvedPostalCode,
            'cp': resolvedPostalCode,
            'dept': canonicalCity.dept,
            'region': canonicalCity.region,
            'category': resolvedCategory,
            'categoryId': categoryId,
            'cityId': cityId,
            'cityCategoryKey':
                (indexed['cityCategoryKey'] ?? '').toString().trim(),
            'description': description.trim(),
            'phone': phone.trim(),
            'price': price,
            'budget': price,
            'budgetValue': price,
            'budgetType': budgetType,
            'isUrgent': isUrgent,
            'publishedAtLabel': result.status.value == 'active'
                ? 'Annonce publiée'
                : (isPublishingSoon
                    ? 'Publication automatique en cours'
                    : 'Annonce en revue'),
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
            'pseudo': ownerDisplayName,
            'displayName': ownerDisplayName,
            'userName': ownerDisplayName,
            'ownerName': ownerDisplayName,
            'ownerId': ownerId,
            'userId': ownerId,
            'status': result.status.value,
            'moderationStatus': result.moderationStatus.value,
            'visibility': result.visibility.value,
            'isMarketplace': true,
            'advertiser': <String, dynamic>{
              'id': ownerId,
              'name': ownerDisplayName,
              'verified': false,
              'avatarUrl': '',
            },
          },
        );
      },
    );

    if (submission == null) {
      throw StateError('La publication a échoué sans retourner de résultat. Réessayez.');
    }
    return submission;
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
