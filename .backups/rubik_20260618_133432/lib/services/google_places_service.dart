import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'firebase_functions_region.dart';

/// Représente une suggestion retournée par l'API Places
class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});
}

class GooglePlacesService {
  final FirebaseFunctions _functions =
      prestoFirebaseFunctions;
  // Conserve l'import http si d'autres fichiers l'utilisent; ici on passe par Cloud Functions.

  /// Autocomplétion de lieux avec paramètres personnalisables
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? types,
    Map<String, String>? componentRestrictions,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'placesAutocomplete',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      final res = await callable.call<dynamic>(<String, dynamic>{
        'input': input,
        'language': 'fr',
        if (types != null) 'types': types,
        if (componentRestrictions != null)
          'componentRestrictions': componentRestrictions,
      });

      final data = (res.data as Map<dynamic, dynamic>);
      final preds = (data['predictions'] as List<dynamic>?) ?? [];
      return preds
          .map((p) => p as Map<dynamic, dynamic>)
          .map((p) => PlaceSuggestion(
                description: (p['description'] ?? '').toString(),
                placeId: (p['placeId'] ?? '').toString(),
              ))
          .where((p) => p.description.isNotEmpty && p.placeId.isNotEmpty)
          .toList(growable: false);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('PLACES AUTOCOMPLETE (CF) error: ${e.code} ${e.message}');
      return [];
    } catch (e) {
      debugPrint('PLACES AUTOCOMPLETE (CF) error: $e');
      return [];
    }
  }

  /// Récupère les détails d'un lieu via son place_id
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final callable = _functions.httpsCallable(
        'placesDetails',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      final res = await callable.call<dynamic>(<String, dynamic>{
        'placeId': placeId,
        'language': 'fr',
      });

      final data = (res.data as Map<dynamic, dynamic>);
      final result = data['result'];

      if (result is Map) {
        return jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('PLACES DETAILS (CF) error: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('PLACES DETAILS (CF) error: $e');
      return null;
    }
  }
}
