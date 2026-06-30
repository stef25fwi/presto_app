import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../config/ai_prompts.dart';
import '../../models/ai/listing_ai_request.dart';
import '../../models/ai/listing_ai_result.dart';
import '../../services/firebase_functions_region.dart';
import '../../utils/retry.dart';
import 'listing_ai_mapper.dart';

typedef OnProgressUpdate = void Function(String stage, double progress);

/// Service amélioré pour extraction de champs d'annonce avec feedback progressif
class EnhancedListingAiService {
  EnhancedListingAiService({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    this.onProgressUpdate,
  })  : _functions = functions ?? prestoFirebaseFunctions,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final OnProgressUpdate? onProgressUpdate;

  Future<String> uploadAudioBytes({
    required String ownerUid,
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
  }) async {
    _reportProgress('uploading', 0.0);

    final normalizedExtension =
        extension.replaceFirst('.', '').trim().toLowerCase();
    final normalizedContentType = contentType.trim().toLowerCase();

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final storagePath =
        'stt/$ownerUid/${timestamp}_recording.$normalizedExtension';
    final ref = _storage.ref(storagePath);

    await retry(
      () => ref
          .putData(
            audioBytes,
            SettableMetadata(contentType: normalizedContentType),
          )
          .timeout(const Duration(seconds: 30)),
      maxAttempts: 3,
      retryIf: (error) {
        if (error is TimeoutException) return true;
        if (error is FirebaseException) {
          return error.code == 'network-error' ||
              error.code == 'retry-limit-exceeded' ||
              error.code == 'unknown';
        }
        return false;
      },
    );

    _reportProgress('uploading', 1.0);
    return storagePath;
  }

  /// Extrait les champs d'une annonce à partir d'audio avec feedback progressif
  Future<ListingAiResult> extractListingFieldsWithFeedback({
    required String ownerUid,
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
    required ListingAiRequest request,
    required Function(String transcription) onTranscriptionReady,
    required Function(Map<String, dynamic> partialData) onPartialExtraction,
  }) async {
    try {
      // 1. Upload l'audio
      _reportProgress('uploading', 0.1);
      final storagePath = await uploadAudioBytes(
        ownerUid: ownerUid,
        audioBytes: audioBytes,
        contentType: contentType,
        extension: extension,
      );
      _reportProgress('uploading', 1.0);

      // 2. Transcribe avec optimisation FR
      _reportProgress('transcribing', 0.0);
      final transcriptionResult = await _transcribeAudio(
        storagePath: storagePath,
        languageCode: 'fr',
      );
      onTranscriptionReady(transcriptionResult['text'] as String? ?? '');
      _reportProgress('transcribing', 1.0);

      // 3. Extrait les champs avec prompts optimisés
      _reportProgress('extracting', 0.0);
      final result = await _extractFieldsWithOptimizedPrompts(
        storagePath: storagePath,
        transcription: transcriptionResult['text'] as String? ?? '',
        request: request,
        onPartialData: onPartialExtraction,
      );
      _reportProgress('extracting', 1.0);

      return result;
    } catch (e) {
      debugPrint('[EnhancedAI] Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _transcribeAudio({
    required String storagePath,
    required String languageCode,
  }) async {
    final callable = _functions.httpsCallable(
      'openAiTranscribeListingAudio',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final response = await retry(
      () => callable.call<dynamic>(<String, dynamic>{
        'storagePath': storagePath,
        'languageCode': languageCode,
        'promptHint': 'Transcription d\'une demande de service',
      }),
      maxAttempts: 2,
      retryIf: (e) {
        if (e is TimeoutException) return true;
        if (e is FirebaseFunctionsException) {
          return e.code == 'unavailable' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'internal';
        }
        return false;
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<ListingAiResult> _extractFieldsWithOptimizedPrompts({
    required String storagePath,
    required String transcription,
    required ListingAiRequest request,
    required Function(Map<String, dynamic>) onPartialData,
  }) async {
    final callable = _functions.httpsCallable(
      'openAiExtractListingFields',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    // Préparer le prompt amélioré
    final userPrompt = AiPrompts.extractListingFieldsUserPromptTemplate
        .replaceAll('{transcript}', transcription)
        .replaceAll(
            '{category}', request.category.isEmpty ? 'Autre' : request.category)
        .replaceAll('{city}', request.city);

    final response = await retry(
      () => callable.call<dynamic>(<String, dynamic>{
        'hint': userPrompt,
        'systemPrompt': AiPrompts.extractListingFieldsSystemPrompt,
        'city': request.city,
        'category': request.category,
        'lang': 'fr',
      }),
      maxAttempts: 2,
      retryIf: (e) {
        if (e is TimeoutException) return true;
        if (e is FirebaseFunctionsException) {
          return e.code == 'unavailable' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'internal';
        }
        return false;
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    // Notifier des données partielles pour feedback immédiat
    if (data.containsKey('result')) {
      onPartialData(Map<String, dynamic>.from(
        (data['result'] as Map).cast<String, dynamic>(),
      ));
    }

    return ListingAiMapper.fromAudioCallableResponse(data);
  }

  void _reportProgress(String stage, double progress) {
    onProgressUpdate?.call(stage, progress.clamp(0.0, 1.0));
  }
}

/// Messages d'erreur améliorés en français
class AiErrorMessages {
  static String formatError(Object error) {
    if (error is FirebaseFunctionsException) {
      return _formatFirebaseFunctionsError(error);
    }
    if (error is TimeoutException) {
      return 'Analyse trop longue. Réessaie ou raccourcis l\'enregistrement.';
    }
    if (error is FirebaseException) {
      return 'Erreur de communication. Vérifie ta connexion internet.';
    }
    return 'Une erreur est survenue. Réessaie.';
  }

  static String _formatFirebaseFunctionsError(
      FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Reconnecte-toi pour continuer.';
      case 'permission-denied':
        return 'Tu n\'as pas les permissions pour cette action.';
      case 'resource-exhausted':
        return 'Service surchargé. Réessaie dans quelques instants.';
      case 'unavailable':
        return 'Service temporairement indisponible. Réessaie.';
      case 'deadline-exceeded':
      case 'timeout':
        return 'Analyse trop longue. Réessaie avec un enregistrement plus court.';
      case 'invalid-argument':
        return 'Format audio invalide. Utilise WAV ou MP3.';
      case 'internal':
        return 'Erreur serveur. Réessaie dans quelques instants.';
      default:
        return 'Erreur: ${error.message ?? error.code}';
    }
  }
}
