import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/firebase_contract.dart';
import '../constants/validation_constants.dart';
import '../data/marketplace/listing_read_repository.dart';
import '../data/marketplace/listing_repository.dart';
import '../data/marketplace/marketplace_listing_ui_mapper.dart';
import '../models/marketplace_listing_draft.dart';
import 'firebase_functions_region.dart';
import 'city_search.dart';
import 'french_city_postal_validator.dart';
import 'marketplace_human_verification.dart';
import 'offer_indexing.dart';
import 'user_profile_bootstrap_service.dart';

class MarketplacePublishResult {
  final String listingId;
  final Map<String, dynamic> detailData;
  final bool isPubliclyVisible;

  const MarketplacePublishResult({
    required this.listingId,
    required this.detailData,
    required this.isPubliclyVisible,
  });
}

class _ProcessedOfferPhotoPayload {
  final String storagePath;
  final String downloadUrl;
  final String thumbnailUrl;
  final int? width;
  final int? height;
  final String? mimeType;
  final int? sizeBytes;

  const _ProcessedOfferPhotoPayload({
    required this.storagePath,
    required this.downloadUrl,
    required this.thumbnailUrl,
    this.width,
    this.height,
    this.mimeType,
    this.sizeBytes,
  });

  factory _ProcessedOfferPhotoPayload.fromMap(Map<String, dynamic> data) {
    final storagePath = (data['storagePath'] ?? '').toString().trim();
    final downloadUrl = (data['downloadUrl'] ?? '').toString().trim();
    final thumbnailUrl =
        ((data['thumbnailUrl'] ?? data['downloadUrl']) ?? '').toString().trim();
    final mimeType = (data['mimeType'] ?? '').toString().trim();

    if (storagePath.isEmpty || downloadUrl.isEmpty || thumbnailUrl.isEmpty) {
      throw StateError(
        'Le traitement photo n\'a pas renvoyé les métadonnées attendues.',
      );
    }

    return _ProcessedOfferPhotoPayload(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      width: data['width'] is num ? (data['width'] as num).toInt() : null,
      height: data['height'] is num ? (data['height'] as num).toInt() : null,
      mimeType: mimeType.isEmpty ? null : mimeType,
      sizeBytes:
          data['sizeBytes'] is num ? (data['sizeBytes'] as num).toInt() : null,
    );
  }

  ListingMediaInput toListingMediaInput() {
    return ListingMediaInput(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      width: width,
      height: height,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }
}

class MarketplacePublishService {
  MarketplacePublishService({
    ListingRepository? listingRepository,
    ListingReadRepository? listingReadRepository,
    FirebaseStorage? storage,
    MarketplaceHumanVerification? verification,
  })  : _listingRepository = listingRepository ?? ListingRepository(),
        _listingReadRepository =
            listingReadRepository ?? ListingReadRepository(),
        _storageOverride = storage,
      _functions = prestoFirebaseFunctions,
        _verification = verification ?? const MarketplaceHumanVerification();

  final ListingRepository _listingRepository;
  final ListingReadRepository _listingReadRepository;
  final FirebaseStorage? _storageOverride;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;
  final FirebaseFunctions _functions;
  final MarketplaceHumanVerification _verification;

  @visibleForTesting
  static String buildRawPhotoStoragePathForTest({
    required String uid,
    required String draftId,
    required int index,
    required String extension,
    int? timestampMs,
  }) {
    final effectiveTimestamp = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    return StoragePaths.listingDraftRaw(
      uid: uid,
      draftId: draftId,
      fileName: '${effectiveTimestamp}_$index.$extension',
    );
  }

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
      throw StateError(
          'Le titre doit contenir au moins ${ListingValidation.titleMinLength} caractères.');
    }
    if (trimmedTitle.length > ListingValidation.titleMaxLength) {
      throw StateError(
          'Le titre doit contenir au maximum ${ListingValidation.titleMaxLength} caractères.');
    }
    if (trimmedDescription.length < ListingValidation.descriptionMinLength) {
      throw StateError(
          'La description doit contenir au moins ${ListingValidation.descriptionMinLength} caractères.');
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

  Future<String> _obtainRequiredRecaptchaToken(
    MarketplaceHumanVerificationAction action,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = (await _runWithChannelRetry<String>(
        stepLabel: 'vérification humaine',
        fallbackValue: '',
        action: () => _verification.obtainToken(action),
      ))
          .trim();
      if (token.isNotEmpty) {
        return token;
      }

      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    throw StateError(
      'La vérification anti-abus est indisponible pour le moment. Recharge la page puis réessaie.',
    );
  }

  bool _isFirestorePermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  Future<void> _prepareProtectedFirestoreWrite(
    String ownerId, {
    required bool forceRefreshAppCheckToken,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.trim() != ownerId.trim()) {
      return;
    }

    await UserProfileBootstrapService.prepareProfileFirestoreAccess(
      user: user,
      forceRefreshToken: true,
      forceRefreshAppCheckToken: forceRefreshAppCheckToken,
    );
  }

  Future<T> _runProtectedDraftWrite<T>({
    required String ownerId,
    required String stepLabel,
    required Future<T> Function() action,
  }) async {
    try {
      await _prepareProtectedFirestoreWrite(
        ownerId,
        forceRefreshAppCheckToken: false,
      );
    } catch (error) {
      debugPrint(
        '[MarketplacePublish] Initial App Check preflight failed before $stepLabel; trying Firestore write: $error',
      );
    }
    try {
      return await _runWithChannelRetry<T>(
        stepLabel: stepLabel,
        action: action,
      );
    } catch (error) {
      if (!_isFirestorePermissionDenied(error)) rethrow;
    }

    await _prepareProtectedFirestoreWrite(
      ownerId,
      forceRefreshAppCheckToken: true,
    );
    return _runWithChannelRetry<T>(
      stepLabel: stepLabel,
      action: action,
    );
  }

  Future<List<ListingMediaInput>> _uploadPhotos({
    required String uid,
    required String draftId,
    required List<XFile> photos,
  }) async {
    final processOfferPhotoCallable = _functions.httpsCallable(
      'processOfferPhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final media = <ListingMediaInput>[];
    for (var index = 0; index < photos.length; index += 1) {
      final photo = photos[index];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _storageExtension(photo);
      final contentType = _storageContentType(photo);
      final rawPath = buildRawPhotoStoragePathForTest(
        uid: uid,
        draftId: draftId,
        index: index,
        extension: extension,
        timestampMs: timestamp,
      );

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

      try {
        final processedResponse =
            await _runWithChannelRetry<HttpsCallableResult<dynamic>>(
          stepLabel: 'traitement photo',
          action: () => processOfferPhotoCallable.call(<String, dynamic>{
            'draftId': draftId,
            'listingId': draftId,
            'storagePath': rawPath,
          }),
        );

        final processedData = Map<String, dynamic>.from(
          (processedResponse.data as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        );
        final processedPhoto =
            _ProcessedOfferPhotoPayload.fromMap(processedData);
        media.add(processedPhoto.toListingMediaInput());
      } catch (_) {
        try {
          await ref.delete();
        } catch (deleteError) {
          debugPrint(
            '[MarketplacePublish] raw media cleanup failed for $rawPath after processing error: $deleteError',
          );
        }
        rethrow;
      }
    }

    return media;
  }

  Future<void> _deleteUploadedMediaBestEffort(
      List<ListingMediaInput> media) async {
    for (final entry in media) {
      final storagePath = entry.storagePath.trim();
      if (storagePath.isEmpty) continue;
      try {
        await _storage.ref().child(storagePath).delete();
      } catch (error) {
        debugPrint(
            '[MarketplacePublish] raw media rollback failed for $storagePath: $error');
      }
    }
  }

  CityRecord? _resolveCanonicalCity({
    required String city,
    required String postalCode,
  }) {
    return FrenchCityPostalValidator.instance.resolveCanonicalCity(
      city: city,
      postalCode: postalCode,
    );
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

    final locationValidation = FrenchCityPostalValidator.instance.validate(
      city: inputCity,
      postalCode: resolvedPostalCode,
    );
    if (!locationValidation.isKnownCity) {
      throw StateError(
        'Choisissez une ville dans la liste ou vérifiez l\'orthographe.',
      );
    }
    if (resolvedPostalCode.isNotEmpty && !locationValidation.postalCodeMatches) {
      throw StateError('Le code postal ne correspond pas à cette ville.');
    }

    final canonicalCity = locationValidation.canonicalCity!;

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
    final draftId = await _runProtectedDraftWrite<String>(
      ownerId: ownerId,
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
      : await _uploadPhotos(uid: ownerId, draftId: draftId, photos: photos);

    try {
      // 3. Mettre à jour le draft avec les media si nécessaire
      if (media.isNotEmpty) {
        await _runProtectedDraftWrite<void>(
          ownerId: ownerId,
          stepLabel: 'mise à jour media draft',
          action: () => _listingRepository.updateDraftMedia(
            draftId: draftId,
            media: media,
          ),
        );
      }

      final recaptchaToken = await _obtainRequiredRecaptchaToken(
        MarketplaceHumanVerificationAction.listingSubmit,
      );
      final submission = await _runWithChannelRetry<MarketplacePublishResult?>(
        stepLabel: 'publication finale',
        action: () async {
          final result = await _listingRepository.submitDraft(
            draftId: draftId,
            recaptchaToken: recaptchaToken,
          );
          final listingData = await _listingReadRepository.getListingData(
            result.listingId,
          );
          if (listingData == null) {
            throw StateError('Annonce publiee introuvable apres soumission.');
          }
          final isPublic = isPublicActiveListingData(listingData);
          return MarketplacePublishResult(
            listingId: result.listingId,
            detailData: isPublic
                ? mapMarketplaceListingToOfferUi(
                    listingId: result.listingId,
                    data: listingData,
                  )
                : const <String, dynamic>{},
            isPubliclyVisible: isPublic,
          );
        },
      );

      if (submission == null) {
        throw StateError(
            'La publication a échoué sans retourner de résultat. Réessayez.');
      }
      return submission;
    } catch (_) {
      await _deleteUploadedMediaBestEffort(media);
      rethrow;
    }
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
