import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../config/env/openai_config.dart';
import '../../features/micro_ia/micro_ia_service.dart';
import '../../models/ai/audio_transcription_result.dart';
import '../../models/ai/listing_ai_request.dart';
import '../../models/ai/listing_ai_result.dart';
import '../../services/firebase_functions_region.dart';
import '../../utils/retry.dart';
import 'listing_ai_mapper.dart';

typedef ListingAudioSecureUploadPreparer = Future<void> Function({
  required bool forceRefreshToken,
  required bool forceRefreshAppCheckToken,
});
typedef ListingAudioStorageWriter = Future<void> Function({
  required String storagePath,
  required Uint8List audioBytes,
  required String contentType,
});
typedef ListingAudioCallableInvoker = Future<Object?> Function({
  required String name,
  required Duration timeout,
  required Map<String, dynamic> parameters,
});

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
    ListingAudioSecureUploadPreparer? secureUploadPreparer,
    ListingAudioStorageWriter? storageWriter,
    ListingAudioCallableInvoker? callableInvoker,
  })  : _injectedFunctions = functions,
        _injectedStorage = storage,
        _secureUploadPreparer = secureUploadPreparer,
        _storageWriter = storageWriter,
        _callableInvoker = callableInvoker;

  final FirebaseFunctions? _injectedFunctions;
  final FirebaseStorage? _injectedStorage;
  final ListingAudioSecureUploadPreparer? _secureUploadPreparer;
  final ListingAudioStorageWriter? _storageWriter;
  final ListingAudioCallableInvoker? _callableInvoker;

  FirebaseFunctions get _functions =>
      _injectedFunctions ?? prestoFirebaseFunctions;
  FirebaseStorage get _storage => _injectedStorage ?? FirebaseStorage.instance;

  @visibleForTesting
  static Map<String, dynamic> asMapForTest(Object? value) => _asMap(value);

  @visibleForTesting
  static bool shouldRetryCallableForTest(Object error) =>
      _shouldRetryCallable(error);

  @visibleForTesting
  static bool isRetryableStorageWriteErrorForTest(Object error) =>
      _isRetryableStorageWriteError(error);

  @visibleForTesting
  static bool isStorageAuthErrorForTest(Object error) =>
      _isStorageAuthError(error);

  static bool _isRetryableStorageWriteError(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return error.code == 'network-error' ||
          error.code == 'retry-limit-exceeded' ||
          error.code == 'unknown';
    }
    return false;
  }

  static bool _isStorageAuthError(Object error) {
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
    final override = _secureUploadPreparer;
    if (override != null) {
      await override(
        forceRefreshToken: forceRefreshToken,
        forceRefreshAppCheckToken: forceRefreshAppCheckToken,
      );
      return;
    }

    final secureContext = await MicroIaService.prepareSecureCallableContext(
      forceRefreshToken: forceRefreshToken,
      forceRefreshAppCheckToken: forceRefreshAppCheckToken,
    );

    if (!secureContext.hasAppCheckToken) {
      final refreshedContext =
          await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
      if (!refreshedContext.hasAppCheckToken) {
        throw const MicroIaClientAuthException(
          code: 'appcheck-missing',
          message:
              'La verification de securite n\'est pas disponible. Recharge la page puis reessaie.',
        );
      }
    }
  }

  Future<void> _writeStorage({
    required String storagePath,
    required Uint8List audioBytes,
    required String contentType,
  }) async {
    final writer = _storageWriter;
    if (writer != null) {
      await writer(
        storagePath: storagePath,
        audioBytes: audioBytes,
        contentType: contentType,
      ).timeout(OpenAiConfig.uploadTimeout);
      return;
    }

    final ref = _storage.ref(storagePath);
    await ref
        .putData(
          audioBytes,
          SettableMetadata(contentType: contentType),
        )
        .timeout(OpenAiConfig.uploadTimeout);
  }

  Future<Object?> _invokeCallable({
    required String name,
    required Duration timeout,
    required Map<String, dynamic> parameters,
  }) async {
    final override = _callableInvoker;
    if (override != null) {
      return override(
        name: name,
        timeout: timeout,
        parameters: parameters,
      );
    }

    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final response = await callable.call<dynamic>(parameters);
    return response.data;
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

    await _prepareProtectedStorageUpload();

    Future<void> uploadOnce() {
      return retry<void>(
        () => _writeStorage(
          storagePath: storagePath,
          audioBytes: audioBytes,
          contentType: normalizedContentType,
        ),
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
    final responseData = await retry<Object?>(
      () => _invokeCallable(
        name: OpenAiConfig.transcribeListingAudioCallable,
        timeout: OpenAiConfig.audioTimeout,
        parameters: <String, dynamic>{
          'storagePath': storagePath,
          'languageCode': languageCode,
        },
      ),
      maxAttempts: 2,
      retryIf: _shouldRetryCallable,
    );

    final data = _asMap(responseData);
    final transcription = _asMap(data['transcription']);
    return AudioTranscriptionResult.fromMap(transcription);
  }

  Future<ListingAiResult> extractListingFieldsFromUploadedAudio({
    required String storagePath,
    required ListingAiRequest request,
  }) async {
    final responseData = await retry<Object?>(
      () => _invokeCallable(
        name: OpenAiConfig.extractListingFieldsFromAudioCallable,
        timeout: OpenAiConfig.audioTimeout,
        parameters: <String, dynamic>{
          'storagePath': storagePath,
          ...request.toCallablePayload(),
        },
      ),
      maxAttempts: 2,
      retryIf: _shouldRetryCallable,
    );

    final data = _asMap(responseData);
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
