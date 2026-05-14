import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../config/env/openai_config.dart';
import '../../features/micro_ia/micro_ia_service.dart';
import '../../models/ai/audio_transcription_result.dart';
import '../../models/ai/listing_ai_request.dart';
import '../../models/ai/listing_ai_result.dart';
import '../../services/firebase_functions_region.dart';
import '../../utils/retry.dart';
import 'listing_ai_mapper.dart';

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a Map payload from Cloud Functions');
}

bool _shouldRetryCallable(Object error) {
  if (error is TimeoutException) return true;
  if (error is FirebaseFunctionsException) {
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'internal' ||
        error.code == 'resource-exhausted';
  }
  return false;
}

class ListingAudioAiService {
  ListingAudioAiService({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _injectedFunctions = functions,
        _injectedStorage = storage;

  final FirebaseFunctions? _injectedFunctions;
  final FirebaseStorage? _injectedStorage;

  FirebaseFunctions get _functions =>
      _injectedFunctions ?? prestoFirebaseFunctions;
  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  bool _isRetryableStorageWriteError(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return error.code == 'network-error' ||
          error.code == 'retry-limit-exceeded' ||
          error.code == 'unknown';
    }
    return false;
  }

  bool _isStorageAuthError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'unauthorized' ||
          error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }
    return false;
  }

  Future<void> _prepareProtectedStorageUpload({
    bool forceRefreshToken = false,
    bool forceRefreshAppCheckToken = false,
  }) async {
    final secureContext = await MicroIaService.prepareSecureCallableContext(
      forceRefreshToken: forceRefreshToken,
      forceRefreshAppCheckToken: forceRefreshAppCheckToken,
    );

    if (!secureContext.hasAppCheckToken) {
      final refreshedContext = await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
      if (!refreshedContext.hasAppCheckToken) {
        throw const MicroIaClientAuthException(
          code: 'appcheck-missing',
          message: 'La verification de securite n\'est pas disponible. Recharge la page puis reessaie.',
        );
      }
    }
  }

  Future<String> uploadAudioBytes({
    required String ownerUid,
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
    String storagePrefix = 'stt',
  }) async {
    final normalizedExtension =
        extension.replaceFirst('.', '').trim().toLowerCase();
    final normalizedContentType = contentType.trim().toLowerCase();

    if (!OpenAiConfig.isAllowedAudioContentType(normalizedContentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'Unsupported audio content type.',
      );
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final storagePath = storagePrefix == 'stt_streaming'
        ? '$storagePrefix/$ownerUid/${timestamp}_chunk.$normalizedExtension'
        : '$storagePrefix/${ownerUid}_$timestamp.$normalizedExtension';
    final ref = _storage.ref(storagePath);

    await _prepareProtectedStorageUpload();

    Future<void> uploadOnce() {
      return retry(
        () => ref
            .putData(
              audioBytes,
              SettableMetadata(contentType: normalizedContentType),
            )
            .timeout(OpenAiConfig.uploadTimeout),
        maxAttempts: 3,
        retryIf: _isRetryableStorageWriteError,
      );
    }

    try {
      await uploadOnce();
    } catch (error) {
      if (!_isStorageAuthError(error)) {
        rethrow;
      }

      await _prepareProtectedStorageUpload(
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
      await uploadOnce();
    }

    return storagePath;
  }

  Future<AudioTranscriptionResult> transcribeUploadedAudio({
    required String storagePath,
    String languageCode = OpenAiConfig.defaultLanguageCode,
  }) async {
    final callable = _functions.httpsCallable(
      OpenAiConfig.transcribeListingAudioCallable,
      options: HttpsCallableOptions(timeout: OpenAiConfig.audioTimeout),
    );

    final response = await retry(
      () => callable.call<dynamic>(<String, dynamic>{
        'storagePath': storagePath,
        'languageCode': languageCode,
      }),
      maxAttempts: 2,
      retryIf: _shouldRetryCallable,
    );

    final data = _asMap(response.data);
    final transcription = _asMap(data['transcription']);
    return AudioTranscriptionResult.fromMap(transcription);
  }

  Future<ListingAiResult> extractListingFieldsFromUploadedAudio({
    required String storagePath,
    required ListingAiRequest request,
  }) async {
    final callable = _functions.httpsCallable(
      OpenAiConfig.extractListingFieldsFromAudioCallable,
      options: HttpsCallableOptions(timeout: OpenAiConfig.audioTimeout),
    );

    final response = await retry(
      () => callable.call<dynamic>(<String, dynamic>{
        'storagePath': storagePath,
        ...request.toCallablePayload(),
      }),
      maxAttempts: 2,
      retryIf: _shouldRetryCallable,
    );

    final data = _asMap(response.data);
    return ListingAiMapper.fromAudioCallableResponse(data);
  }

  Future<ListingAiResult> extractListingFieldsFromAudioBytes({
    required String ownerUid,
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
    required ListingAiRequest request,
  }) async {
    final storagePath = await uploadAudioBytes(
      ownerUid: ownerUid,
      audioBytes: audioBytes,
      contentType: contentType,
      extension: extension,
    );
    return extractListingFieldsFromUploadedAudio(
      storagePath: storagePath,
      request: request,
    );
  }
}
