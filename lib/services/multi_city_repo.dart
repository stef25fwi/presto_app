import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CityRecord {
  final String name;
  final String cp;     // "97128"
  final String dept;   // "971" ou "75"
  final String? region;

  CityRecord({
    required this.name,
    required this.cp,
    required this.dept,
    this.region,
  });

  factory CityRecord.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? j['ville'] ?? j['city'] ?? '').toString();
    final cp = (j['cp'] ?? j['postalCode'] ?? j['postcode'] ?? '').toString();
    final dept = (j['dept'] ?? j['department'] ?? '').toString();
    final region = j['region']?.toString();
    return CityRecord(name: name, cp: cp, dept: dept, region: region);
  }
}

class MultiCityRepo {
  // Cache: dept -> cities
  final Map<String, List<CityRecord>> _deptCache = {};
  List<String>? _assetPathsCache;

  /// Liste tous les assets JSON dans assets/data qui contiennent "cities" (ou adapte le filtre si besoin)
  Future<List<String>> listCityAssets() async {
    if (_assetPathsCache != null) return _assetPathsCache!;
    final manifestRaw = await rootBundle.loadString('AssetManifest.json');
    final manifest = (jsonDecode(manifestRaw) as Map).cast<String, dynamic>();

    final paths = manifest.keys
        .where((p) =>
            p.startsWith('assets/data/') &&
            p.endsWith('.json') &&
            p.toLowerCase().contains('cities')) // <- change si tes fichiers s'appellent autrement
        .toList()
      ..sort();

    _assetPathsCache = paths;
    return paths;
  }

  /// Déduit un code département à partir d'un CP FR (DOM: 971/972/..., métropole: 2 chiffres)
  String? deptFromPostalCode(String? cp) {
    if (cp == null) return null;
    final m = RegExp(r'\b(\d{5})\b').firstMatch(cp);
    final code = m?.group(1);
    if (code == null) return null;

    if (code.startsWith('97') || code.startsWith('98')) {
      return code.substring(0, 3); // DOM/TOM
    }
    return code.substring(0, 2); // Métropole
  }

  /// Essaie de retrouver le bon fichier "dept" dans les assets (en se basant sur le nom de fichier)
  Future<String?> _findAssetForDept(String dept) async {
    final assets = await listCityAssets();
    // On cherche un fichier qui contient le dept dans son nom (ex: cities_971.json, cities-971.json, 971.json…)
    for (final p in assets) {
      final lower = p.toLowerCase();
      if (lower.contains(dept)) return p;
    }
    return null;
  }

  Future<List<CityRecord>> loadDept(String dept) async {
    if (_deptCache.containsKey(dept)) return _deptCache[dept]!;

    final asset = await _findAssetForDept(dept);
    if (asset == null) {
      _deptCache[dept] = const [];
      return const [];
    }

    final raw = await rootBundle.loadString(asset);
    final decoded = jsonDecode(raw);

    final List list = decoded is List ? decoded : (decoded['data'] as List? ?? const []);
    final records = list
        .whereType<Map>()
        .map((m) => CityRecord.fromJson(m.cast<String, dynamic>()))
        .where((c) => c.name.isNotEmpty)
        .toList();

    _deptCache[dept] = records;
    return records;
  }

  /// Recherche villes (auto-complétion) : charge le dept lié au CP si fourni, sinon cherche dans depts déjà chargés
  Future<List<CityRecord>> search(String query, {String? cpHint, int limit = 20}) async {
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final dept = deptFromPostalCode(cpHint);

    final List<CityRecord> pool;
    if (dept != null) {
      pool = await loadDept(dept);
    } else {
      // Si pas de CP, on cherche uniquement dans ce qui est déjà chargé (rapide).
      // Option: tu peux décider de charger 971 par défaut en Guadeloupe.
      pool = _deptCache.values.expand((x) => x).toList();
    }

    final res = <CityRecord>[];
    for (final c in pool) {
      final nameN = _normalize(c.name);
      if (nameN.startsWith(q) || nameN.contains(q)) {
        res.add(c);
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"['']"), "'")
      .replaceAll(RegExp(r"[^\p{Letter}\p{Number}\s-]+", unicode: true), ' ')
      .replaceAll(RegExp(r"\s+"), ' ')
      .trim();
}
