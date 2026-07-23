import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../config/env/openai_config.dart';
import '../../models/ai/listing_ai_request.dart';
import '../../services/ai/listing_audio_ai_service.dart';
import '../../utils/recording_path_web.dart'
    if (dart.library.io) '../../utils/recording_path_io.dart';
import '../micro_ia/micro_ia_service.dart';
import '../micro_ia/web_audio_recorder_stub.dart'
    if (dart.library.js_interop) '../micro_ia/web_audio_recorder.dart';
import 'profile_readiness.dart';
import 'publish_ai_state.dart';

/// Orchestrates the publish-AI flow: profile gate → microphone recording →
/// Storage upload → server STT + draft generation → result event.
class PublishAiPipeline {
  PublishAiPipeline({
    ProfileReadinessChecker? readiness,
    ListingAudioAiService? audioService,
    AudioRecorder? recorder,
    WebAudioRecorder? webRecorder,
  })  : _readiness = readiness ?? ProfileReadinessChecker(),
        _audioService = audioService ?? ListingAudioAiService(),
        _recorder = recorder ?? AudioRecorder(),
        _webRecorder = webRecorder ?? WebAudioRecorder();

  final ProfileReadinessChecker _readiness;
  final ListingAudioAiService _audioService;
  final AudioRecorder _recorder;
  final WebAudioRecorder _webRecorder;

  final StreamController<PublishAiState> _events =
      StreamController<PublishAiState>.broadcast();

  Stream<PublishAiState> get events => _events.stream;

  bool _isRecording = false;
  String? _mobileRecordingPath;
  String? _activeUid;

  bool get isRecording => _isRecording;

  Future<void> arm() async {
    if (_isRecording) return;

    _emit(const PublishAiPreparing());

    final readiness = await _readiness.check();
    if (!readiness.isReady) {
      _emit(PublishAiProfileNotReady(
        message: readiness.describe(),
        missingFields: readiness.missingFields,
      ));
      return;
    }
    _activeUid = readiness.user?.uid;

    try {
      if (kIsWeb) {
        await _webRecorder.start();
      } else {
        if (!await _recorder.hasPermission()) {
          _emit(const PublishAiMicUnavailable(
            "Le micro est requis pour la dictée IA. Autorise l'accès dans les "
            'paramètres puis réessaie.',
          ));
          return;
        }
        _mobileRecordingPath = await createTempAudioPath(
          prefix: 'presto',
          extension: 'm4a',
        );
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: _mobileRecordingPath!,
        );
      }
    } catch (error, stackTrace) {
      _mobileRecordingPath = null;
      _emit(PublishAiFailure(
        code: 'mic_start_failed',
        message: _formatMicError(error),
        cause: error,
      ));
      debugPrintStack(stackTrace: stackTrace);
      return;
    }

    _isRecording = true;
    _emit(const PublishAiRecording());
  }

  Future<void> stop() async {
    if (!_isRecording) return;

    _isRecording = false;
    final uid = _activeUid;
    if (uid == null) {
      _emit(const PublishAiFailure(
        code: 'auth_missing',
        message: "Session expirée. Reconnecte-toi et réessaie.",
      ));
      return;
    }

    _emit(const PublishAiUploading());

    final Uint8List audioBytes;
    final String contentType;
    final String extension;
    try {
      if (kIsWeb) {
        final blob = await _webRecorder.stopToBlob();
        final upload = await webBlobToMicroIaUpload(blob, preferRawBytes: true);
        if (upload.bytes.isEmpty) {
          throw const PublishAiPipelineException(
            code: 'audio_empty',
            message: "Audio invalide (fichier vide). Réessaie.",
          );
        }
        if (upload.usedClientSideWavConversion && upload.bytes.length < 30000) {
          throw const PublishAiPipelineException(
            code: 'audio_too_short',
            message: "L'enregistrement est trop court. Réessaie plus longtemps.",
          );
        }
        audioBytes = upload.bytes;
        contentType = upload.contentType;
        extension = upload.extension;
      } else {
        final localPath = await _recorder.stop() ?? _mobileRecordingPath;
        _mobileRecordingPath = null;
        if (localPath == null) {
          throw const PublishAiPipelineException(
            code: 'audio_missing',
            message: 'Aucun fichier audio retourné par le micro.',
          );
        }
        final xfile = XFile(localPath);
        final bytes = await xfile.readAsBytes();
        if (bytes.isEmpty) {
          throw const PublishAiPipelineException(
            code: 'audio_empty',
            message: "Audio invalide (fichier vide). Réessaie.",
          );
        }
        audioBytes = bytes;
        final lower = localPath.toLowerCase();
        final isM4a = lower.endsWith('.m4a');
        final isMp4 = lower.endsWith('.mp4');
        extension = isM4a ? 'm4a' : (isMp4 ? 'mp4' : 'wav');
        contentType = (isM4a || isMp4) ? 'audio/mp4' : 'audio/wav';
      }
    } on PublishAiPipelineException catch (error) {
      _emit(PublishAiFailure(code: error.code, message: error.message));
      return;
    } catch (error) {
      _emit(PublishAiFailure(
        code: 'audio_capture_failed',
        message: _formatMicError(error),
        cause: error,
      ));
      return;
    }

    String storagePath;
    try {
      storagePath = await _audioService.uploadAudioBytes(
        ownerUid: uid,
        audioBytes: audioBytes,
        contentType: contentType,
        extension: extension,
      );
    } catch (error) {
      _emit(PublishAiFailure(
        code: 'upload_failed',
        message: "Impossible d'envoyer l'audio au serveur. Vérifie ta connexion et réessaie.",
        cause: error,
      ));
      return;
    }

    _emit(const PublishAiTranscribing());

    try {
      final response = await MicroIaService.processAudio(
        storagePath: storagePath,
        languageCode: OpenAiConfig.defaultLanguageCode,
        generateDraft: true,
        debugLabel: 'publish_ai_pipeline',
      );
      _emitCombinedResponse(response);
    } on MicroIaClientAuthException catch (error) {
      _emit(PublishAiFailure(
        code: error.code,
        message: error.message,
        cause: error,
      ));
    } on FirebaseFunctionsException catch (error) {
      if (_mustUseOpenAiFallback(error)) {
        final recovered = await _recoverWithOpenAi(storagePath, error);
        if (recovered) return;
      }
      _emit(PublishAiFailure(
        code: error.code,
        message: _friendlyCallableError(error),
        cause: error,
      ));
    } catch (error) {
      _emit(PublishAiFailure(
        code: 'transcribe_failed',
        message: 'La transcription a échoué. Réessaie dans un instant.',
        cause: error,
      ));
    }
  }

  void _emitCombinedResponse(Map<String, dynamic> response) {
    final transcript = (response['text'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      _emit(const PublishAiFailure(
        code: 'transcript_empty',
        message: 'Aucun texte reconnu. Parle un peu plus fort et réessaie.',
      ));
      return;
    }
    final draftRaw = response['draft'];
    final draft = draftRaw is Map ? Map<String, dynamic>.from(draftRaw) : null;
    final modeUsed = (response['modeUsed'] ?? '').toString();
    _emit(PublishAiResult(
      transcript: transcript,
      draft: draft,
      modeUsed: modeUsed,
    ));
  }

  bool _mustUseOpenAiFallback(FirebaseFunctionsException error) {
    return error.code == 'internal' ||
        error.code == 'unavailable' ||
        error.code == 'deadline-exceeded';
  }

  Future<bool> _recoverWithOpenAi(
    String storagePath,
    FirebaseFunctionsException originalError,
  ) async {
    debugPrint(
      '[PublishAiPipeline] combined callable failed (${originalError.code}); '
      'falling back to openAiExtractListingFieldsFromAudio.',
    );
    try {
      final result = await _audioService.extractListingFieldsFromUploadedAudio(
        storagePath: storagePath,
        request: const ListingAiRequest(
          input: '',
          languageCode: OpenAiConfig.defaultLanguageCode,
        ),
      );
      final transcript = result.transcriptText;
      if (transcript.isEmpty) return false;
      _emit(PublishAiResult(
        transcript: transcript,
        draft: result.toDraftPayload(),
        modeUsed: 'WHISPER_FALLBACK',
      ));
      return true;
    } catch (fallbackError, stackTrace) {
      debugPrint(
        '[PublishAiPipeline] OpenAI audio fallback failed: $fallbackError',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  String _friendlyCallableError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'resource-exhausted':
        return 'Trop de demandes successives. Attends un instant puis réessaie.';
      case 'failed-precondition':
        return error.message ?? 'Audio non exploitable. Enregistre un nouvel audio.';
      case 'unauthenticated':
        return "Session expirée. Reconnecte-toi puis réessaie.";
      default:
        return 'La transcription a échoué. Réessaie dans un instant.';
    }
  }

  Future<void> cancel() async {
    if (!_isRecording) return;
    _isRecording = false;
    try {
      if (kIsWeb) {
        await _webRecorder.stopToBlob();
      } else {
        await _recorder.stop();
      }
    } catch (_) {}
    _mobileRecordingPath = null;
    _emit(const PublishAiIdle());
  }

  Future<void> dispose() async {
    await cancel();
    await _events.close();
  }

  void _emit(PublishAiState state) {
    if (_events.isClosed) return;
    _events.add(state);
  }

  String _formatMicError(Object error) {
    final prefix = kIsWeb ? 'Micro web indisponible' : 'Micro indisponible';
    return '$prefix : ${error.toString()}';
  }
}

class PublishAiPipelineException implements Exception {
  const PublishAiPipelineException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}
