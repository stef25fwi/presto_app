/// Event-style state surface emitted by the publish AI pipeline.
///
/// Consumers (typically the publish offer page) listen to the stream and
/// translate events into UI updates (snackbars, busy indicators, form
/// updates). Keeping the state in a sealed hierarchy means the compiler
/// can exhaust-check every branch in the UI switch.
sealed class PublishAiState {
  const PublishAiState();
}

/// Pipeline is idle and ready to start recording.
class PublishAiIdle extends PublishAiState {
  const PublishAiIdle();
}

/// Profile readiness / App Check checks are running.
class PublishAiPreparing extends PublishAiState {
  const PublishAiPreparing();
}

/// Microphone permission denied or device-level capture impossible.
class PublishAiMicUnavailable extends PublishAiState {
  const PublishAiMicUnavailable(this.message);
  final String message;
}

/// User must complete their profile (displayName / city / postalCode) or
/// sign in before they can use the AI button.
class PublishAiProfileNotReady extends PublishAiState {
  const PublishAiProfileNotReady({
    required this.message,
    required this.missingFields,
  });

  final String message;
  final List<String> missingFields;
}

/// Microphone is actively recording. The UI should display a stop button.
class PublishAiRecording extends PublishAiState {
  const PublishAiRecording();
}

/// Audio capture finished; bytes are being uploaded to Firebase Storage.
class PublishAiUploading extends PublishAiState {
  const PublishAiUploading();
}

/// Audio uploaded; the Cloud Function is performing STT + draft generation.
class PublishAiTranscribing extends PublishAiState {
  const PublishAiTranscribing();
}

/// STT and draft generation succeeded. The page is expected to translate
/// [transcript] and [draft] into form updates synchronously and then call
/// [PublishAiPipeline.acknowledge] (no-op in current impl).
class PublishAiResult extends PublishAiState {
  const PublishAiResult({
    required this.transcript,
    required this.draft,
    required this.modeUsed,
  });

  final String transcript;

  /// Raw draft payload returned by the callable (`microIaProcessAudio`).
  /// `null` when the user-requested `generateDraft` flag was `false` or when
  /// the server-side draft step failed without being fatal.
  final Map<String, dynamic>? draft;

  /// STT mode actually used by the backend (`GOOGLE_ONLY`, `WHISPER_ONLY`,
  /// `HYBRID`, …). Useful for the admin diagnostic banner.
  final String modeUsed;
}

/// Terminal error state. UI should display [message]; [code] is for logs.
class PublishAiFailure extends PublishAiState {
  const PublishAiFailure({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;
}
