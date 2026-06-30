import 'package:presto_app/services/city_search.dart';

class FrenchCityPostalValidationResult {
  const FrenchCityPostalValidationResult({
    required this.isValid,
    required this.isKnownCity,
    required this.postalCodeMatches,
    required this.canonicalCity,
  });

  final bool isValid;
  final bool isKnownCity;
  final bool postalCodeMatches;
  final CityRecord? canonicalCity;
}

class _KnownFrenchCity {
  const _KnownFrenchCity({
    required this.city,
    required this.aliases,
    required this.postalCode,
    required this.department,
    required this.inseeCode,
    required this.region,
  });

  final String city;
  final List<String> aliases;
  final String postalCode;
  final String department;
  final String inseeCode;
  final String region;

  CityRecord toCityRecord() {
    return CityRecord(
      name: city,
      postalCode: postalCode,
      departmentCode: department,
      regionCode: region,
    );
  }
}

class FrenchCityPostalValidator {
  FrenchCityPostalValidator._();

  static final FrenchCityPostalValidator instance =
      FrenchCityPostalValidator._();

  static const List<_KnownFrenchCity> _knownCities = <_KnownFrenchCity>[
    _KnownFrenchCity(
      city: 'Sainte-Anne',
      aliases: <String>[
        'Sainte Anne',
        'Sainte-Anne',
        'SAINTE ANNE',
        'STE ANNE',
      ],
      postalCode: '97180',
      department: '971',
      inseeCode: '97128',
      region: 'Guadeloupe',
    ),
  ];

  static String normalizeCity(String input) {
    var value = input.trim().toLowerCase();
    const accented = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };

    accented.forEach((key, replacement) {
      value = value.replaceAll(key, replacement);
    });

    return value
        .replaceAll(RegExp(r"[-'’]+"), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\bste\b'), 'sainte')
        .replaceAll(RegExp(r'\bst\b'), 'saint')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizePostalCode(String input) {
    final match = RegExp(r'\b(97\d{3}|98\d{3}|\d{5})\b').firstMatch(input);
    return match?.group(1)?.trim() ?? input.trim();
  }

  List<CityRecord> searchSuggestions(
    String query, {
    String? postalCodeHint,
    int limit = 10,
  }) {
    final normalizedQuery = normalizeCity(query);
    final normalizedPostalCode = normalizePostalCode(postalCodeHint ?? '');
    if (normalizedQuery.isEmpty && normalizedPostalCode.isEmpty) {
      return const <CityRecord>[];
    }

    final results = <CityRecord>[];
    final seen = <String>{};

    void addCandidate(CityRecord candidate) {
      final key =
          '${candidate.name}|${candidate.postalCode}|${candidate.departmentCode}';
      if (seen.add(key)) {
        results.add(candidate);
      }
    }

    for (final known in _knownCities) {
      final aliasSet = _candidateNames(
        city: known.city,
        aliases: known.aliases,
      );
      final matchesCity = normalizedQuery.isEmpty ||
          aliasSet.any(
            (alias) =>
                alias == normalizedQuery || alias.startsWith(normalizedQuery),
          );
      final matchesPostal = normalizedPostalCode.isEmpty ||
          known.postalCode == normalizedPostalCode;
      if (matchesCity && matchesPostal) {
        addCandidate(known.toCityRecord());
      }
    }

    if (normalizedPostalCode.isNotEmpty) {
      for (final candidate in CitySearch.instance.searchByPostalCode(
        normalizedPostalCode,
        limit: 50,
      )) {
        if (_matchesCandidateCity(candidate, normalizedQuery)) {
          addCandidate(candidate);
        }
      }
    }

    if (normalizedQuery.isNotEmpty) {
      for (final candidate in CitySearch.instance.search(query, limit: 50)) {
        if (normalizedPostalCode.isEmpty ||
            candidate.postalCode == normalizedPostalCode) {
          addCandidate(candidate);
        }
      }
    }

    if (results.isEmpty && normalizedQuery.isNotEmpty) {
      for (final candidate in CitySearch.instance.searchFuzzy(
        query,
        postalCode: normalizedPostalCode.isEmpty ? null : normalizedPostalCode,
        limit: 20,
      )) {
        addCandidate(candidate);
      }
    }

    results.sort((left, right) {
      final leftScore = _scoreCandidate(
        left,
        normalizedCity: normalizedQuery,
        normalizedPostalCode: normalizedPostalCode,
      );
      final rightScore = _scoreCandidate(
        right,
        normalizedCity: normalizedQuery,
        normalizedPostalCode: normalizedPostalCode,
      );
      if (leftScore != rightScore) {
        return rightScore.compareTo(leftScore);
      }
      final postalCompare = left.postalCode.compareTo(right.postalCode);
      if (postalCompare != 0) {
        return postalCompare;
      }
      return left.name.compareTo(right.name);
    });

    if (results.length <= limit) {
      return results;
    }
    return results.take(limit).toList(growable: false);
  }

  CityRecord? resolveCanonicalCity({
    String? city,
    String? postalCode,
  }) {
    final normalizedCity = normalizeCity(city ?? '');
    final normalizedPostalCode = normalizePostalCode(postalCode ?? '');

    if (normalizedCity.isEmpty && normalizedPostalCode.isEmpty) {
      return null;
    }

    final candidates = searchSuggestions(
      city ?? '',
      postalCodeHint: normalizedPostalCode,
      limit: 50,
    );

    if (candidates.isEmpty && normalizedPostalCode.isNotEmpty) {
      final byPostal =
          CitySearch.instance.pickBestForPostalCode(normalizedPostalCode);
      if (byPostal != null &&
          (normalizedCity.isEmpty ||
              _matchesCandidateCity(byPostal, normalizedCity))) {
        return byPostal;
      }
    }

    for (final candidate in candidates) {
      final exactCity = normalizedCity.isEmpty ||
          _candidateNames(city: candidate.name).contains(normalizedCity);
      final exactPostal = normalizedPostalCode.isEmpty ||
          candidate.postalCode == normalizedPostalCode;
      if (exactCity && exactPostal) {
        return candidate;
      }
    }

    if (normalizedCity.isNotEmpty) {
      for (final candidate in candidates) {
        if (_candidateNames(city: candidate.name).contains(normalizedCity)) {
          return candidate;
        }
      }
    }

    if (normalizedPostalCode.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate.postalCode == normalizedPostalCode) {
          return candidate;
        }
      }
    }

    return candidates.isEmpty ? null : candidates.first;
  }

  CityRecord? resolveExactTypedCity({
    required String city,
    String? postalCode,
  }) {
    final normalizedCity = normalizeCity(city);
    if (normalizedCity.isEmpty) {
      return null;
    }

    final candidate = resolveCanonicalCity(city: city, postalCode: postalCode);
    if (candidate == null) {
      return null;
    }

    final names = _candidateNames(city: candidate.name);
    if (!names.contains(normalizedCity)) {
      return null;
    }

    final normalizedPostalCode = normalizePostalCode(postalCode ?? '');
    if (normalizedPostalCode.isNotEmpty &&
        candidate.postalCode != normalizedPostalCode) {
      return null;
    }

    return candidate;
  }

  FrenchCityPostalValidationResult validate({
    required String city,
    required String postalCode,
  }) {
    final normalizedCity = normalizeCity(city);
    final normalizedPostalCode = normalizePostalCode(postalCode);

    final knownCity = resolveExactTypedCity(city: city) ??
        resolveCanonicalCity(city: city, postalCode: '');
    if (normalizedCity.isEmpty || knownCity == null) {
      return const FrenchCityPostalValidationResult(
        isValid: false,
        isKnownCity: false,
        postalCodeMatches: false,
        canonicalCity: null,
      );
    }

    if (normalizedPostalCode.isEmpty) {
      return FrenchCityPostalValidationResult(
        isValid: true,
        isKnownCity: true,
        postalCodeMatches: true,
        canonicalCity: knownCity,
      );
    }

    final resolved = resolveCanonicalCity(city: city, postalCode: postalCode);
    final postalMatches = resolved != null &&
        resolved.postalCode == normalizedPostalCode &&
        _candidateNames(city: resolved.name).contains(normalizedCity);

    return FrenchCityPostalValidationResult(
      isValid: postalMatches,
      isKnownCity: true,
      postalCodeMatches: postalMatches,
      canonicalCity: postalMatches ? resolved : knownCity,
    );
  }

  static Set<String> _candidateNames({
    required String city,
    List<String> aliases = const <String>[],
  }) {
    final names = <String>{normalizeCity(city)};
    for (final alias in aliases) {
      names.add(normalizeCity(alias));
    }

    final base = normalizeCity(city);
    if (base.contains('sainte')) {
      names.add(base.replaceAll('sainte', 'ste'));
    }
    if (base.contains('saint')) {
      names.add(base.replaceAll('saint', 'st'));
    }

    final known =
        _knownCities.where((entry) => normalizeCity(entry.city) == base);
    for (final entry in known) {
      for (final alias in entry.aliases) {
        names.add(normalizeCity(alias));
      }
    }

    return names.where((value) => value.isNotEmpty).toSet();
  }

  static bool _matchesCandidateCity(
      CityRecord candidate, String normalizedCity) {
    if (normalizedCity.isEmpty) {
      return true;
    }
    final names = _candidateNames(city: candidate.name);
    return names.any(
      (name) =>
          name == normalizedCity ||
          name.startsWith(normalizedCity) ||
          _isVeryCloseCityName(name, normalizedCity),
    );
  }

  static int _scoreCandidate(
    CityRecord candidate, {
    required String normalizedCity,
    required String normalizedPostalCode,
  }) {
    var score = 0;
    final names = _candidateNames(city: candidate.name);
    if (normalizedPostalCode.isNotEmpty &&
        candidate.postalCode == normalizedPostalCode) {
      score += 4;
    }
    if (normalizedCity.isNotEmpty) {
      if (names.contains(normalizedCity)) {
        score += 4;
      } else if (names.any((name) => name.startsWith(normalizedCity))) {
        score += 2;
      } else if (names.any((name) => name.contains(normalizedCity))) {
        score += 1;
      } else if (names
          .any((name) => _isVeryCloseCityName(name, normalizedCity))) {
        score += 2;
      }
    }
    return score;
  }

  static bool _isVeryCloseCityName(String candidate, String query) {
    final left = candidate.replaceAll(' ', '');
    final right = query.replaceAll(' ', '');
    if (left.isEmpty || right.isEmpty) {
      return false;
    }

    final maxDistance = _maxFuzzyDistanceFor(
        left.length > right.length ? left.length : right.length);
    return _levenshteinDistance(left, right) <= maxDistance;
  }

  static int _maxFuzzyDistanceFor(int length) {
    if (length <= 4) return 1;
    return 2;
  }

  static int _levenshteinDistance(String left, String right) {
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

  static int _min3(int a, int b, int c) {
    final ab = a < b ? a : b;
    return ab < c ? ab : c;
  }
}
