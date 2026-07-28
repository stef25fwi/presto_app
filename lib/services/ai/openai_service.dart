import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../config/env/openai_config.dart';
import '../../models/ai/listing_ai_request.dart';
import '../../models/ai/listing_ai_result.dart';
import '../../services/firebase_functions_region.dart';
import '../../utils/retry.dart';
import 'listing_ai_mapper.dart';

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a Map payload from Cloud Functions');
}

bool _shouldRetryCallable(Object error) {
  if (error is TimeoutException) return true;
  if (error is FirebaseFunctionsException) {
    // Le backend possède désormais sa propre politique OpenAI et une clé
    // d'idempotence. On ne répète côté client que les pannes de transport sûres.
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded';
  }
  return false;
}

class OpenAiService {
  OpenAiService({FirebaseFunctions? functions})
      : _functions = functions ?? prestoFirebaseFunctions;

  final FirebaseFunctions _functions;

  Future<ListingAiResult> extractListingFieldsFromText(
    ListingAiRequest request,
  ) async {
    final callable = _functions.httpsCallable(
      OpenAiConfig.extractListingFieldsCallable,
      options: HttpsCallableOptions(timeout: OpenAiConfig.textTimeout),
    );

    final response = await retry(
      () => callable.call<dynamic>(request.toCallablePayload()),
      maxAttempts: 2,
      retryIf: _shouldRetryCallable,
    );

    final data = _asMap(response.data);
    return ListingAiMapper.fromTextCallableResponse(data);
  }
}
