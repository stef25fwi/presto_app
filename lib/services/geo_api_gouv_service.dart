import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Résultat normalisé depuis Geo API Gouv.
/// Source : https://geo.api.gouv.fr/communes
class GeoApiGouvCommune {
  const GeoApiGouvCommune({
    required this.name,
    required this.inseeCode,
    required this.postalCodes,
    required this.departmentCode,
    required this.regionCode,
  });

  final String name;
  final String inseeCode;
  final List<String> postalCodes;
  final String departmentCode;
  final String regionCode;

  String get primaryPostalCode => postalCodes.isEmpty ? '' : postalCodes.first;

  bool matchesPostalCode(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    return postalCodes.contains(normalized);
  }

  factory GeoApiGouvCommune.fromJson(Map<String, dynamic> json) {
    final rawPostalCodes = json['codesPostaux'];
    final postalCodes = rawPostalCodes is List
        ? rawPostalCodes.map((e) => e.toString()).toList(growable: false)
        : <String>[];

    return GeoApiGouvCommune(
      name: (json['nom'] ?? '').toString(),
      inseeCode: (json['code'] ?? '').toString(),
      postalCodes: postalCodes,
      departmentCode: (json['codeDepartement'] ?? '').toString(),
      regionCode: (json['codeRegion'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestoreLocationFields({
    String locationSource = 'geo_api_gouv',
  }) {
    return <String, dynamic>{
      'communeName': name,
      'postalCode': primaryPostalCode,
      'inseeCode': inseeCode,
      'departmentCode': departmentCode,
      'regionCode': regionCode,
      'locationSource': locationSource,
    };
  }
}

/// Service isolé pour Geo API Gouv.
/// Il ne remplace pas encore l'ancien système local.
/// Il pourra être utilisé en priorité avec fallback sur CitySearch / FrenchCityPostalValidator.
class GeoApiGouvService {
  GeoApiGouvService({
    http.Client? client,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _baseUri = baseUri ?? Uri.parse('https://geo.api.gouv.fr');

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;

  final Map<String, List<GeoApiGouvCommune>> _cache =
      <String, List<GeoApiGouvCommune>>{};

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<List<GeoApiGouvCommune>> findCommunesByPostalCode(
    String postalCode, {
    int limit = 20,
  }) async {
    final normalizedPostalCode = _digitsOnly(postalCode);
    if (normalizedPostalCode.length != 5) {
      return const <GeoApiGouvCommune>[];
    }

    return _getCommunes(
      cacheKey: 'cp:$normalizedPostalCode:$limit',
      queryParameters: <String, String>{
        'codePostal': normalizedPostalCode,
        'fields': 'nom,code,codesPostaux,codeDepartement,codeRegion',
        'format': 'json',
      },
      postalCodeFilter: normalizedPostalCode,
      limit: limit,
    );
  }

  Future<List<GeoApiGouvCommune>> searchCommunesByName(
    String query, {
    String? postalCodeHint,
    List<String>? allowedDepartmentCodes,
    int limit = 20,
  }) async {
    final trimmedQuery = query.trim();
    final normalizedPostalCode = _digitsOnly(postalCodeHint ?? '');

    if (trimmedQuery.length < 2 && normalizedPostalCode.length != 5) {
      return const <GeoApiGouvCommune>[];
    }

    if (normalizedPostalCode.length == 5 && trimmedQuery.length < 2) {
      return findCommunesByPostalCode(normalizedPostalCode, limit: limit);
    }

    final params = <String, String>{
      'nom': trimmedQuery,
      'fields': 'nom,code,codesPostaux,codeDepartement,codeRegion',
      'format': 'json',
      'boost': 'population',
      'limit': limit.toString(),
    };

    final results = await _getCommunes(
      cacheKey:
          'name:${trimmedQuery.toLowerCase()}:cp:$normalizedPostalCode:$limit',
      queryParameters: params,
      postalCodeFilter:
          normalizedPostalCode.length == 5 ? normalizedPostalCode : null,
      limit: limit,
    );

    if (allowedDepartmentCodes == null || allowedDepartmentCodes.isEmpty) {
      return results;
    }

    final allowed = allowedDepartmentCodes.map((e) => e.trim()).toSet();

    return results
        .where((commune) => allowed.contains(commune.departmentCode))
        .take(limit)
        .toList(growable: false);
  }

  Future<List<GeoApiGouvCommune>> _getCommunes({
    required String cacheKey,
    required Map<String, String> queryParameters,
    String? postalCodeFilter,
    required int limit,
  }) async {
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final uri = _baseUri.replace(
      path: '${_baseUri.path}/communes'.replaceAll('//', '/'),
      queryParameters: queryParameters,
    );

    try {
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode != 200) {
        return const <GeoApiGouvCommune>[];
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return const <GeoApiGouvCommune>[];
      }

      final results = decoded
          .whereType<Map<String, dynamic>>()
          .map(GeoApiGouvCommune.fromJson)
          .where((commune) => commune.name.trim().isNotEmpty)
          .where((commune) {
            if (postalCodeFilter == null || postalCodeFilter.isEmpty) {
              return true;
            }
            return commune.matchesPostalCode(postalCodeFilter);
          })
          .take(limit)
          .toList(growable: false);

      _cache[cacheKey] = results;
      return results;
    } on TimeoutException {
      return const <GeoApiGouvCommune>[];
    } on Object {
      return const <GeoApiGouvCommune>[];
    }
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
