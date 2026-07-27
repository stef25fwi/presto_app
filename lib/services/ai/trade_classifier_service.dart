import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../data/trade_category_lookup.dart';
import '../../services/firebase_functions_region.dart';

typedef TradeClassifierCaller = Future<Object?> Function(
  Map<String, dynamic> parameters,
);

/// Résultat complet d'une classification photo.
class TradeClassificationResult {
  final String? metier;
  final double confidence;

  /// Null si [confidence] < [kTradeConfidenceThreshold] ou si [metier] inconnu.
  final TradeCategoryMatch? match;

  const TradeClassificationResult({
    required this.metier,
    required this.confidence,
    required this.match,
  });

  bool get isConfident => match != null;
}

/// Appelle `classifyServicePhoto` (Cloud Function) avec une URL d'image,
/// puis résout localement la catégorie via [kTradeLookup].
class TradeClassifierService {
  TradeClassifierService({TradeClassifierCaller? caller}) : _caller = caller;

  final TradeClassifierCaller? _caller;

  FirebaseFunctions get _functions => prestoFirebaseFunctions;

  Future<TradeClassificationResult> classifyFromUrl(String imageUrl) async {
    return _classify({'imageUrl': imageUrl});
  }

  Future<TradeClassificationResult> classifyFromBase64(
    String base64Data, {
    String mimeType = 'image/jpeg',
  }) async {
    return _classify({
      'imageBase64': base64Data,
      'mimeType': mimeType,
    });
  }

  Future<Object?> _call(Map<String, dynamic> params) async {
    final caller = _caller;
    if (caller != null) return caller(params);
    final callable = _functions.httpsCallable(
      'classifyServicePhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call<dynamic>(params);
    return result.data;
  }

  Future<TradeClassificationResult> _classify(
    Map<String, dynamic> params,
  ) async {
    final raw = await _call(params);
    final data = Map<dynamic, dynamic>.from(raw as Map);

    final metier = data['metier']?.toString();
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

    TradeCategoryMatch? match;
    if (metier != null && confidence >= kTradeConfidenceThreshold) {
      match = kTradeLookup[metier];
    }

    return TradeClassificationResult(
      metier: metier,
      confidence: confidence,
      match: match,
    );
  }
}
