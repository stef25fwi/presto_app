class OpenAiConfig {
  const OpenAiConfig._();

  static const String extractListingFieldsCallable =
      'openAiExtractListingFields';
  static const String extractListingFieldsFromAudioCallable =
      'openAiExtractListingFieldsFromAudio';
  static const String transcribeListingAudioCallable =
      'openAiTranscribeListingAudio';

  static const String defaultLanguageCode = 'fr-FR';
  static const Duration textTimeout = Duration(seconds: 45);
  static const Duration audioTimeout = Duration(seconds: 90);
  static const Duration uploadTimeout = Duration(seconds: 60);

  static const Set<String> allowedAudioContentTypes = <String>{
    'audio/wav',
    'audio/x-wav',
    'audio/wave',
    'audio/vnd.wave',
    'audio/webm',
    'video/webm',
    'audio/mp4',
    'video/mp4',
    'audio/x-m4a',
    'audio/aac',
  };

  static bool isAllowedAudioContentType(String rawContentType) {
    final contentType = rawContentType.trim().toLowerCase();
    return allowedAudioContentTypes.contains(contentType);
  }
}
