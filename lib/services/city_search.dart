import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

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

  bool _loaded = false;
  final List<CityRecord> _allCities = [];

  /// ====== CHARGEMENT DES FICHIERS JSON ======
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    // même logique que ce qu'on avait déjà : boucle sur cities_XX.json
    final List<String> files = [
      'assets/data/cities/cities_01.json',
      'assets/data/cities/cities_02.json',
      'assets/data/cities/cities_03.json',
      'assets/data/cities/cities_04.json',
      'assets/data/cities/cities_05.json',
      'assets/data/cities/cities_06.json',
      'assets/data/cities/cities_07.json',
      'assets/data/cities/cities_08.json',
      'assets/data/cities/cities_09.json',
      'assets/data/cities/cities_10.json',
      // ...
      // laisse ici tous tes fichiers jusqu'à 976
      'assets/data/cities/cities_971.json',
      'assets/data/cities/cities_972.json',
      'assets/data/cities/cities_973.json',
      'assets/data/cities/cities_974.json',
      'assets/data/cities/cities_976.json',
    ];

    for (final path in files) {
      try {
        final raw = await rootBundle.loadString(path);
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        for (final row in list) {
          final map = row as Map<String, dynamic>;
          _allCities.add(
            CityRecord(
              name: map['name'] as String,
              postalCode: map['cp'] as String,
              departmentCode: map['dept'] as String,
              regionCode: map['region'] as String,
            ),
          );
        }
      } catch (_) {
        // on ignore les fichiers manquants
      }
    }

    _loaded = true;
  }

  /// ====== NORMALISATION POUR IGNORER ACCENTS / TIRETS ======
  String _normalize(String input) {
    final lower = input.toLowerCase();
    const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ\'`^¨';
    const plain =  'aaaaaaceeeeiiiinooooouuuuyy ';

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

  /// Recherche par nom de ville (auto-complétion synchrone)
  /// ✅ + filtre optionnel par départements autorisés
  /// ✅ Alias pour "Paris" → tous les arrondissements
  List<CityRecord> search(
    String query, {
    int limit = 50, // Augmenté de 20 à 50
    List<String>? allowedDeptCodes, // ✅ AJOUT
  }) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final allowed = (allowedDeptCodes == null || allowedDeptCodes.isEmpty)
        ? null
        : allowedDeptCodes.toSet();

    final results = <CityRecord>[];

    // 🔶 Alias spécial : si l'utilisateur tape "paris" (exact après normalisation),
    // retourner TOUS les arrondissements de Paris
    if (q == 'paris') {
      for (final city in _allCities) {
        if (allowed != null && !allowed.contains(city.departmentCode)) {
          continue;
        }
        final nameNorm = _normalize(city.name);
        if (nameNorm.startsWith('paris')) {
          results.add(city);
          if (results.length >= limit) break;
        }
      }
      if (results.isNotEmpty) return results;
    }

    // Recherche normale : startsWith
    for (final city in _allCities) {
      // ✅ Filtrage dept si fourni
      if (allowed != null && !allowed.contains(city.departmentCode)) {
        continue;
      }

      final nameNorm = _normalize(city.name);
      if (nameNorm.startsWith(q)) {
        results.add(city);
        if (results.length >= limit) break;
      }
    }

    // Optionnel: si pas assez de résultats, on élargit en contains
    if (results.length < limit) {
      for (final city in _allCities) {
        if (results.length >= limit) break;

        if (allowed != null && !allowed.contains(city.departmentCode)) {
          continue;
        }

        final nameNorm = _normalize(city.name);
        if (!results.contains(city) && nameNorm.contains(q)) {
          results.add(city);
        }
      }
    }

    return results;
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

    // On réutilise la méthode search() déjà existante
    final results =
        _allCities.where((c) => c.postalCode.startsWith(query)).toList()
          ..sort((a, b) {
            final cmp = a.postalCode.compareTo(b.postalCode);
            if (cmp != 0) return cmp;
            return a.name.compareTo(b.name);
          });

    return results.take(limit).toList();
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
}
