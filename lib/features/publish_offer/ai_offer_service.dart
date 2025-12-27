import 'package:cloud_functions/cloud_functions.dart';

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
        title: m['title'] as String?,
        description: m['description'] as String?,
        category: m['category'] as String?,
        city: m['city'] as String?,
        postalCode: m['postalCode'] as String?,
        bullets: m['bullets'] != null ? List<String>.from(m['bullets'] as List) : null,
        constraints: m['constraints'] != null
            ? List<String>.from(m['constraints'] as List)
            : null,
      );
}

class AiOfferService {
  /// Génère un brouillon à partir d'un texte (sans audio)
  static Future<OfferDraft> generateDraft({
    required String hint,
    required String currentCity,
    required String currentCategory,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable(
      'generateOfferDraft',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
    );
    final res = await callable.call({
      'hint': hint,
      'city': currentCity,
      'category': currentCategory,
      'lang': 'fr',
    });

    final data = Map<String, dynamic>.from(res.data as Map);
    return OfferDraft.fromMap(data);
  }

  /// Transcription Premium (Chirp 3) + Rédaction IA
  static Future<({String transcript, OfferDraft draft})> transcribeAndDraft({
    required String gcsUri,
    required String languageCode,
    required String category,
    required String city,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable(
      'transcribeAndDraftOffer',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    final res = await callable.call({
      'gcsUri': gcsUri,
      'languageCode': languageCode,
      'category': category,
      'city': city,
    });

    final data = Map<String, dynamic>.from(res.data as Map);
    final transcript = (data['transcript'] ?? '').toString();
    final draftMap = Map<String, dynamic>.from(data['draft'] as Map);
    final draft = OfferDraft.fromMap(draftMap);

    return (transcript: transcript, draft: draft);
  }
}
