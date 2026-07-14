import 'audio_transcription_result.dart';

List<String> _stringListFromDynamic(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

double? _doubleFromValue(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class ListingAiResult {
  const ListingAiResult({
    required this.title,
    required this.description,
    this.category,
    this.price,
    this.currency,
    this.city,
    this.department,
    this.postalCode,
    this.listingType,
    this.urgency,
    this.contactPreference,
    this.keywords = const <String>[],
    this.details = const <String>[],
    this.missingFields = const <String>[],
    this.questionsToAsk = const <String>[],
    this.confidenceScore,
    this.transcription,
  });

  final String title;
  final String description;
  final String? category;
  final double? price;
  final String? currency;
  final String? city;
  final String? department;
  final String? postalCode;
  final String? listingType;
  final String? urgency;
  final String? contactPreference;
  final List<String> keywords;
  final List<String> details;
  final List<String> missingFields;
  final List<String> questionsToAsk;
  final double? confidenceScore;
  final AudioTranscriptionResult? transcription;

  String get transcriptText => transcription?.text.trim() ?? '';

  factory ListingAiResult.empty({AudioTranscriptionResult? transcription}) {
    return ListingAiResult(
      title: '',
      description: '',
      transcription: transcription,
    );
  }

  factory ListingAiResult.fromMap(
    Map<String, dynamic> map, {
    AudioTranscriptionResult? transcription,
  }) {
    return ListingAiResult(
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      category: map['category']?.toString().trim(),
      price: _doubleFromValue(map['price']),
      currency: map['currency']?.toString().trim(),
      city: map['city']?.toString().trim(),
      department: map['department']?.toString().trim(),
      postalCode: map['postalCode']?.toString().trim(),
      listingType: map['listingType']?.toString().trim(),
      urgency: map['urgency']?.toString().trim(),
      contactPreference: map['contactPreference']?.toString().trim(),
      keywords: _stringListFromDynamic(map['keywords']),
      details: _stringListFromDynamic(map['details']),
      missingFields: _stringListFromDynamic(map['missingFields']),
      questionsToAsk: _stringListFromDynamic(map['questionsToAsk']),
      confidenceScore: _doubleFromValue(map['confidenceScore']),
      transcription: transcription,
    );
  }

  Map<String, dynamic> toDraftPayload() {
    final rawCurrency = currency?.trim();
    final normalizedCurrency = rawCurrency == null || rawCurrency.isEmpty
        ? 'EUR'
        : rawCurrency.toUpperCase();

    return <String, dynamic>{
      'title': title,
      'titre': title,
      'description': description,
      'description_courte': description,
      'category': category,
      'categorie': category,
      'city': city,
      'ville': city,
      'department': department,
      'postalCode': postalCode,
      'listingType': listingType,
      'urgence': urgency,
      'contactPreference': contactPreference,
      'budgetType': price != null ? 'fixed' : null,
      'budget': <String, dynamic>{
        'type': price != null ? 'fixe' : null,
        'min': price,
        'max': price,
        'devise': normalizedCurrency,
      },
      'details': details,
      'keywords': keywords,
      'missingFields': missingFields,
      'questions_a_poser': questionsToAsk,
      'questionsToAsk': questionsToAsk,
      'confidenceScore': confidenceScore,
      if (transcription != null) 'transcript': transcription!.text,
    };
  }
}
