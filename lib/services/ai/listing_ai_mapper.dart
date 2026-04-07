import '../../models/ai/audio_transcription_result.dart';
import '../../models/ai/listing_ai_result.dart';

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

class ListingAiMapper {
  const ListingAiMapper._();

  static ListingAiResult fromTextCallableResponse(Map<String, dynamic> data) {
    final resultPayload = _extractResultPayload(data);
    return ListingAiResult.fromMap(resultPayload);
  }

  static ListingAiResult fromAudioCallableResponse(Map<String, dynamic> data) {
    final resultPayload = _extractResultPayload(data);
    final transcriptionPayload = _asMap(data['transcription']);
    final transcription = transcriptionPayload.isEmpty
        ? null
        : AudioTranscriptionResult.fromMap(transcriptionPayload);
    return ListingAiResult.fromMap(
      resultPayload,
      transcription: transcription,
    );
  }

  static Map<String, dynamic> toPublishDraft(ListingAiResult result) {
    return result.toDraftPayload();
  }

  static Map<String, dynamic> _extractResultPayload(Map<String, dynamic> data) {
    final nested = _asMap(data['result']);
    if (nested.isNotEmpty) {
      return nested;
    }
    return data;
  }
}
