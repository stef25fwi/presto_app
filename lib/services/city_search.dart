import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../constants.dart';

/// Modèle ville minimal
class CityRecord {
  final String name;
  final String postalCode;
  final String departmentCode;
  final String regionCode;

  CityRecord({
    required this.name,
    required this.postalCode,
    required this.departmentCode,
    required this.regionCode,
  });

  // 🔌 Adaptateurs pour le reste du code
  String get cp => postalCode;
  String get dept => departmentCode;
  String get region => regionCode;
}

class CitySearch {
  CitySearch._internal();
  static final CitySearch instance = CitySearch._internal();

  static const List<String> _overseasCityAssetSuffixes = <String>[
    '971',
    '972',
    '973',
    '974',
    '975',
    '976',
    '980',
    '986',
    '987',
    '988',
  ];

  static const Map<String, String> _extraRegionLabelsByDepartment =
      <String, String>{
        '975': 'Saint-Pierre-et-Miquelon',
        '980': 'Monaco',
        '986': 'Wallis-et-Futuna',
        '987': 'Polynésie française',
        '988': 'Nouvelle-Calédonie',
      };

  bool _loaded = false;
  final List<CityRecord> _allCities = [];

  List<String> _cityAssetPaths() {
    final metro = <String>[
      for (var dept = 1; dept <= 95; dept++)
        if (dept != 20)
          'assets/data/cities/cities_${dept.toString().padLeft(2, '0')}.json',
    ];

    return <String>[
      ...metro,
      'assets/data/cities/cities_2A.json',
      'assets/data/cities/cities_2B.json',
      ..._overseasCityAssetSuffixes
          .map((suffix) => 'assets/data/cities/cities_$suffix.json'),
    ];
  }

  String _resolveRegionLabel({
    required String rawRegion,
    required String departmentCode,
  }) {
    final trimmedRegion = rawRegion.trim();
    if (trimmedRegion.isNotEmpty) {
      return kRegions[trimmedRegion] ?? trimmedRegion;
    }

    for (final entry in kRegionDepartments.entries) {
      if (entry.value.contains(departmentCode)) {
        return kRegions[entry.key] ?? entry.key;
      }
    }

    return _extraRegionLabelsByDepartment[departmentCode] ??
        kDepartments[departmentCode] ??
        '';
  }

  /// ====== CHARGEMENT DES FICHIERS JSON ======
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final files = _cityAssetPaths();

    for (final path in files) {
      try {
        final raw = await rootBundle.loadString(path);
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        for (final row in list) {
          final map = row as Map<String, dynamic>;
          final departmentCode = (map['dept'] ?? '').toString();
          _allCities.add(
            CityRecord(
              name: (map['name'] ?? '').toString(),
              postalCode: (map['cp'] ?? '').toString(),
              departmentCode: departmentCode,
              regionCode: _resolveRegionLabel(
                rawRegion: (map['region'] ?? '').toString(),
                departmentCode: departmentCode,
              ),
            ),
          );
        }
      } catch (_) {
        // on ignore les fichiers manquants
      }
    }

    // Fallback: manually inject missing critical cities.
    final hasMelun = _allCities.any((c) => c.name.toLowerCase() == 'melun');
    if (!hasMelun) {
      _allCities.add(
        CityRecord(
          name: 'Melun',
          postalCode: '77000',
          departmentCode: '77',
          regionCode: '11', // Île-de-France
        ),
      );
    }

    _loaded = true;
  }

  /// ====== NORMALISATION POUR IGNORER ACCENTS / TIRETS ======
  String _normalize(String input) {
    final lower = input.toLowerCase();
    const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ\'`^¨';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy ';

    final buffer = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final ch = lower[i];

      // Supprime espaces, tirets et apostrophes pour tolérer "lesabymes" vs "Les Abymes".
      if (ch == ' ' || ch == '-' || ch == '\'') {
        continue;
      }

      final idx = accents.indexOf(ch);
      if (idx >= 0) {
        buffer.write(plain[idx]);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  List<String> _deptCandidatesFromPostalCode(String postalCode) {
    final trimmed = postalCode.trim();
    if (trimmed.length < 2) {
      return const <String>[];
    }
    if (trimmed.startsWith('97') || trimmed.startsWith('98')) {
      return trimmed.length >= 3 ? <String>[trimmed.substring(0, 3)] : const <String>[];
    }
    if (trimmed.startsWith('20')) {
      return const <String>['2A', '2B'];
    }
    return <String>[trimmed.substring(0, 2)];
  }

  int _scoreCandidate(
    CityRecord city, {
    required String normalizedQuery,
    required String postalCodeHint,
  }) {
    final normalizedName = _normalize(city.name);
    var score = 0;

    if (postalCodeHint.isNotEmpty) {
      if (city.postalCode == postalCodeHint) {
        score += 10;
      } else if (city.postalCode.startsWith(postalCodeHint)) {
        score += 4;
      }
    }

    if (normalizedName == normalizedQuery) {
      score += 12;
    } else if (normalizedName.startsWith(normalizedQuery)) {
      score += 8;
    } else if (normalizedQuery.length < 5 && normalizedName.contains(normalizedQuery)) {
      score += 3;
    } else {
      final distance = _levenshteinDistance(normalizedQuery, normalizedName);
      if (distance <= _maxFuzzyDistanceFor(normalizedQuery.length)) {
        score += 2;
      }
    }

    if (normalizedName.replaceAll(' ', '') == normalizedQuery.replaceAll(' ', '')) {
      score += 2;
    }

    return score;
  }

  List<CityRecord> _dedupe(List<CityRecord> cities) {
    final seen = <String>{};
    final results = <CityRecord>[];
    for (final city in cities) {
      final key =
          '${_normalize(city.name)}|${city.postalCode}|${city.departmentCode}|${city.regionCode}';
      if (seen.add(key)) {
        results.add(city);
      }
    }
    return results;
  }

  /// Recherche par nom de ville (auto-complétion synchrone)
  /// ✅ + filtre optionnel par départements autorisés
  /// ✅ Alias pour "Paris" → tous les arrondissements
  List<CityRecord> search(
    String query, {
    int limit = 50, // Augmenté de 20 à 50
    List<String>? allowedDeptCodes, // ✅ AJOUT
    String? postalCodeHint,
  }) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final postalHint = postalCodeHint?.trim() ?? '';
    final deptCandidates = postalHint.isEmpty
        ? const <String>[]
        : _deptCandidatesFromPostalCode(postalHint);
    final allowed = (allowedDeptCodes == null || allowedDeptCodes.isEmpty)
        ? null
        : <String>{...allowedDeptCodes, ...deptCandidates};

    final exact = <CityRecord>[];
    final prefix = <CityRecord>[];
    final contains = <CityRecord>[];
    final fuzzy = <({CityRecord city, int score})>[];

    for (final city in _allCities) {
      if (allowed != null && !allowed.contains(city.departmentCode)) {
        continue;
      }
      if (postalHint.isNotEmpty &&
          !city.postalCode.startsWith(postalHint) &&
          deptCandidates.isNotEmpty &&
          !deptCandidates.contains(city.departmentCode)) {
        continue;
      }

      final nameNorm = _normalize(city.name);
      if (nameNorm == q) {
        exact.add(city);
        continue;
      }
      if (nameNorm.startsWith(q)) {
        prefix.add(city);
        continue;
      }
      if (q.length < 5 && nameNorm.contains(q)) {
        contains.add(city);
        continue;
      }

      final score = _scoreCandidate(
        city,
        normalizedQuery: q,
        postalCodeHint: postalHint,
      );
      if (score > 0) {
        fuzzy.add((city: city, score: score));
      }
    }

    final sortedFuzzy = fuzzy
        .where((entry) => !exact.contains(entry.city) && !prefix.contains(entry.city))
        .toList()
      ..sort((left, right) {
        final byScore = right.score.compareTo(left.score);
        if (byScore != 0) {
          return byScore;
        }
        final byPostal = left.city.postalCode.compareTo(right.city.postalCode);
        if (byPostal != 0) {
          return byPostal;
        }
        return left.city.name.compareTo(right.city.name);
      });

    final ordered = <CityRecord>[
      ...exact,
      ...prefix,
      ...contains,
      ...sortedFuzzy.map((entry) => entry.city),
    ];

    final deduped = _dedupe(ordered);
    return deduped.take(limit).toList(growable: false);
  }

  /// Recherche par **nom de ville** (préfixe strict)
  Future<List<CityRecord>> searchByNamePrefix(String rawQuery,
      {int limit = 20}) async {
    await ensureLoaded();
    final q = _normalize(rawQuery.trim());
    if (q.isEmpty) return const [];

    final results = _allCities.where((c) {
      final n = _normalize(c.name);
      return n.startsWith(q);
    }).toList();

    results.sort((a, b) => a.name.compareTo(b.name));
    return results.take(limit).toList();
  }

  /// Recherche par **code postal** (préfixe strict)
  Future<List<CityRecord>> searchByPostalPrefix(String rawPostal,
      {int limit = 20}) async {
    await ensureLoaded();
    final q = rawPostal.trim();
    if (q.isEmpty) return const [];

    final results = _allCities.where((c) => c.postalCode.startsWith(q)).toList()
      ..sort((a, b) {
        final cmp = a.postalCode.compareTo(b.postalCode);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });

    return results.take(limit).toList();
  }

  /// Entrée unique pour l'UI : on détecte si l'utilisateur tape un CP ou un nom
  Future<List<CityRecord>> searchSuggestions(String input,
      {int limit = 20}) async {
    final q = input.trim();
    if (q.isEmpty) return const [];

    final isPostal = RegExp(r'^\d+$').hasMatch(q);
    if (isPostal) {
      return searchByPostalPrefix(q, limit: limit);
    } else {
      return searchByNamePrefix(q, limit: limit);
    }
  }

  /// Recherche par code postal (utilisé dans la page "Je publie une offre")
  List<CityRecord> searchByPostalCode(String postalCode, {int limit = 50}) {
    final query = postalCode.trim();
    if (query.isEmpty) return const [];

    final results = _dedupe(
        _allCities.where((c) => c.postalCode.startsWith(query)).toList())
          ..sort((a, b) {
            final aExact = a.postalCode == query;
            final bExact = b.postalCode == query;
            if (aExact != bExact) {
              return aExact ? -1 : 1;
            }
            final cmp = a.postalCode.compareTo(b.postalCode);
            if (cmp != 0) return cmp;
            return a.name.compareTo(b.name);
          });

    return results.take(limit).toList();
  }

  List<CityRecord> searchFuzzy(
    String query, {
    String? postalCode,
    int limit = 20,
  }) {
    final normalizedQuery = _normalize(query);
    final normalizedPostalCode = postalCode?.trim() ?? '';
    if (normalizedQuery.isEmpty) return const [];

    final maxDistance = _maxFuzzyDistanceFor(normalizedQuery.length);
    final scored = <({CityRecord city, int distance})>[];

    for (final city in _allCities) {
      if (normalizedPostalCode.isNotEmpty && city.postalCode != normalizedPostalCode) {
        continue;
      }

      final normalizedName = _normalize(city.name);
      final distance = _levenshteinDistance(normalizedQuery, normalizedName);
      if (distance > maxDistance) {
        continue;
      }

      scored.add((city: city, distance: distance));
    }

    scored.sort((left, right) {
      final byDistance = left.distance.compareTo(right.distance);
      if (byDistance != 0) return byDistance;

      final byPostal = left.city.postalCode.compareTo(right.city.postalCode);
      if (byPostal != 0) return byPostal;

      return left.city.name.compareTo(right.city.name);
    });

    return scored.take(limit).map((entry) => entry.city).toList(growable: false);
  }

  /// Choisit la meilleure ville pour un CP : d'abord match exact, sinon le 1er résultat
  CityRecord? pickBestForPostalCode(String postalCode) {
    final trimmed = postalCode.trim();
    if (trimmed.isEmpty) return null;

    final results = searchByPostalCode(trimmed, limit: 50);
    if (results.isEmpty) return null;

    // Match exact si possible
    for (final c in results) {
      if (c.postalCode == trimmed) return c;
    }
    // Sinon premier résultat
    return results.first;
  }

  int _maxFuzzyDistanceFor(int length) {
    if (length <= 4) return 1;
    return 2;
  }

  int _levenshteinDistance(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = i + 1;

      for (var j = 0; j < right.length; j++) {
        final substitutionCost = left[i] == right[j] ? 0 : 1;
        current[j + 1] = _min3(
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + substitutionCost,
        );
      }

      previous = current;
    }

    return previous[right.length];
  }

  int _min3(int a, int b, int c) {
    final ab = a < b ? a : b;
    return ab < c ? ab : c;
  }
}
