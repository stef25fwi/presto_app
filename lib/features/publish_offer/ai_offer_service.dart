import 'package:cloud_functions/cloud_functions.dart';

List<String>? _stringListOrNull(Object? value) {
  if (value == null) return null;
  if (value is List) {
    final out = <String>[];
    for (final item in value) {
      if (item == null) continue;
      out.add(item.toString());
    }
    return out;
  }
  return null;
}

Map<String, dynamic> _mapStringDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a Map payload from Cloud Functions');
}

class OfferDraft {
  final String? title;
  final String? description;
  final String? category;
  final String? city;
  final String? postalCode;
  final List<String>? bullets;
  final List<String>? constraints;

  OfferDraft({
    this.title,
    this.description,
    this.category,
    this.city,
    this.postalCode,
    this.bullets,
    this.constraints,
  });

  factory OfferDraft.fromMap(Map<String, dynamic> m) => OfferDraft(
        title: m['title']?.toString(),
        description: m['description']?.toString(),
        category: m['category']?.toString(),
        city: m['city']?.toString(),
        postalCode: m['postalCode']?.toString(),
        bullets: _stringListOrNull(m['bullets']),
        constraints: _stringListOrNull(m['constraints']),
      );
}

class AiOfferService {
  /// Génère un brouillon à partir d'un texte (sans audio)
  static Future<OfferDraft> generateDraft({
    required String hint,
    required String currentCity,
    required String currentCategory,
    FirebaseFunctions? functions,
  }) async {
    final callable =
        (functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'))
            .httpsCallable(
      'generateOfferDraft',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );
    final res = await callable.call({
      'hint': hint,
      'city': currentCity,
      'category': currentCategory,
      'lang': 'fr',
    });

    final data = _mapStringDynamic(res.data);
    return OfferDraft.fromMap(data);
  }

  /// Transcription Premium (Chirp 3) + Rédaction IA
  static Future<({String transcript, OfferDraft draft})> transcribeAndDraft({
    required String gcsUri,
    required String languageCode,
    required String category,
    required String city,
    FirebaseFunctions? functions,
  }) async {
    final callable =
        (functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'))
            .httpsCallable(
      'transcribeAndDraftOffer',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    final res = await callable.call({
      'gcsUri': gcsUri,
      'languageCode': languageCode,
      'category': category,
      'city': city,
    });

    final data = _mapStringDynamic(res.data);
    final transcript = (data['transcript'] ?? '').toString();
    final draftMap = _mapStringDynamic(data['draft']);
    final draft = OfferDraft.fromMap(draftMap);

    return (transcript: transcript, draft: draft);
  }
}
