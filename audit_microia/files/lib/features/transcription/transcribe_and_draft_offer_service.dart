import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';

Map<String, dynamic> _mapStringDynamic(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a Map payload from Cloud Functions');
}

class TranscribeAndDraftOfferResult {
  final String transcript;
  final String title;
  final String description;
  final String category;
  final String city;
  final String postalCode;

  const TranscribeAndDraftOfferResult({
    required this.transcript,
    required this.title,
    required this.description,
    required this.category,
    required this.city,
    required this.postalCode,
  });

  factory TranscribeAndDraftOfferResult.fromData(Map<String, dynamic> data) {
    return TranscribeAndDraftOfferResult(
      transcript: (data['transcript'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      postalCode: (data['postalCode'] ?? '').toString(),
    );
  }
}

class TranscribeAndDraftOfferService {
  final FirebaseFunctions _functions;

  TranscribeAndDraftOfferService({FirebaseFunctions? functions})
      : _functions =
        functions ?? prestoFirebaseFunctions;

  Future<TranscribeAndDraftOfferResult> transcribeAndDraftOffer({
    required String gcsUri,
    required String languageCode,
  }) async {
    final callable = _functions.httpsCallable(
      'transcribeAndDraftOffer',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );

    final res = await callable.call<dynamic>({
      'gcsUri': gcsUri,
      'languageCode': languageCode,
    });

    final data = _mapStringDynamic(res.data);
    return TranscribeAndDraftOfferResult.fromData(data);
  }
}
