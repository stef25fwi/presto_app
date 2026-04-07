double? _doubleFromDynamic(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class AudioTranscriptionResult {
  const AudioTranscriptionResult({
    required this.text,
    required this.provider,
    required this.languageCode,
    this.storagePath,
    this.confidence,
    this.durationSeconds,
  });

  final String text;
  final String provider;
  final String languageCode;
  final String? storagePath;
  final double? confidence;
  final double? durationSeconds;

  bool get hasText => text.trim().isNotEmpty;

  factory AudioTranscriptionResult.fromMap(Map<String, dynamic> map) {
    return AudioTranscriptionResult(
      text: (map['text'] ?? '').toString(),
      provider: (map['provider'] ?? '').toString(),
      languageCode: (map['languageCode'] ?? '').toString(),
      storagePath: map['storagePath']?.toString(),
      confidence: _doubleFromDynamic(map['confidence']),
      durationSeconds: _doubleFromDynamic(map['durationSeconds']),
    );
  }
}
