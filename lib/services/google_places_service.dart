import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../google_places_config.dart';

/// Représente une suggestion retournée par l'API Places
class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});
}

class GooglePlacesService {
  final http.Client _client = http.Client();

  /// Autocomplétion de lieux avec paramètres personnalisables
  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? types,
    Map<String, String>? componentRestrictions,
  }) async {
    final queryParams = <String, String>{
      'input': input,
      'language': 'fr',
      'key': kGooglePlacesApiKey,
    };

    if (types != null) {
      queryParams['types'] = types;
    }

    if (componentRestrictions != null) {
      final components = componentRestrictions.entries
          .map((e) => '${e.key}:${e.value}')
          .join('|');
      queryParams['components'] = components;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      queryParams,
    );

    final resp = await _client.get(url);

    debugPrint('PLACES AUTOCOMPLETE status=${resp.statusCode}');

    if (resp.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      debugPrint('PLACES ERROR: ${data['status']} - ${data['error_message']}');
      return [];
    }

    final predictions = (data['predictions'] as List<dynamic>?) ?? [];

    final results = predictions
        .map((p) => p as Map<String, dynamic>)
        .map((p) => PlaceSuggestion(
              description: (p['description'] ?? '').toString(),
              placeId: (p['place_id'] ?? '').toString(),
            ))
        .toList(growable: false);

    return results;
  }

  /// Récupère les détails d'un lieu via son place_id
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'address_components',
        'language': 'fr',
        'key': kGooglePlacesApiKey,
      },
    );

    final resp = await _client.get(url);

    debugPrint('PLACES DETAILS status=${resp.statusCode}');

    if (resp.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      debugPrint('PLACES DETAILS ERROR: ${data['status']} - ${data['error_message']}');
      return null;
    }

    return data['result'] as Map<String, dynamic>?;
  }
}