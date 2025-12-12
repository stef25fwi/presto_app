import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CityRecord {
  final String name;
  final String cp;
  final String dept;
  final String region;

  CityRecord({
    required this.name,
    required this.cp,
    required this.dept,
    required this.region,
  });

  factory CityRecord.fromJson(Map<String, dynamic> j) => CityRecord(
        name: (j['name'] ?? '').toString(),
        cp: (j['cp'] ?? '').toString(),
        dept: (j['dept'] ?? '').toString(),
        region: (j['region'] ?? '').toString(),
      );
}

class CityRepo {
  // cache par dept ("971", "75", ...)
  final Map<String, List<CityRecord>> _cache = {};
  List<String>? _cityAssets; // liste des assets cities/*.json

  Future<List<String>> _listCityAssets() async {
    if (_cityAssets != null) return _cityAssets!;
    final manifestRaw = await rootBundle.loadString('AssetManifest.json');
    final manifest = (jsonDecode(manifestRaw) as Map).cast<String, dynamic>();

    _cityAssets = manifest.keys
        .where((p) =>
            p.startsWith('assets/data/cities/') &&
            p.endsWith('.json'))
        .toList()
      ..sort();

    return _cityAssets!;
  }

  /// "97128" -> "971"
  /// "75012" -> "75"
  /// "20000" -> "2A" (heuristique)
  /// "20200" -> "2B" (heuristique)
  String? deptFromCp(String text) {
    final m = RegExp(r'\b(\d{5})\b').firstMatch(text);
    final cp = m?.group(1);
    if (cp == null) return null;

    // DOM/TOM
    if (cp.startsWith('97') || cp.startsWith('98')) return cp.substring(0, 3);

    // Corse : codes postaux "20xxx" -> 2A ou 2B (heuristique)
    // Exemples: Ajaccio 20000 = 2A ; Bastia 20200 = 2B.
    if (cp.startsWith('20')) {
      final n = int.tryParse(cp) ?? 0;
      return (n < 20200) ? '2A' : '2B';
    }

    // Métropole
    return cp.substring(0, 2);
  }

  /// Construit le nom EXACT du fichier:
  /// 01..09 -> cities_01.json (zéro devant)
  /// 10..95 -> cities_75.json
  /// 2A/2B -> cities_2A.json
  /// 971.. -> cities_971.json
  String _deptToFileToken(String dept) {
    final d = dept.toUpperCase().trim();

    if (d == '2A' || d == '2B') return d;

    // DOM/TOM: 3 chiffres
    if (RegExp(r'^\d{3}$').hasMatch(d)) return d;

    // Métropole: 1-2 chiffres
    final n = int.tryParse(d);
    if (n != null) {
      if (n >= 0 && n <= 9) return n.toString().padLeft(2, '0');
      return n.toString(); // 10..95
    }

    return d;
  }

  Future<String?> _findAssetForDept(String dept) async {
    final token = _deptToFileToken(dept);
    final candidate = 'assets/data/cities/cities_$token.json';

    // on vérifie que l'asset existe bien dans le manifest
    final assets = await _listCityAssets();
    if (assets.contains(candidate)) return candidate;

    // fallback: recherche "contains"
    for (final p in assets) {
      if (p.toLowerCase().contains('cities_${token.toLowerCase()}.json')) {
        return p;
      }
    }
    return null;
  }

  Future<List<CityRecord>> loadDept(String dept) async {
    if (_cache.containsKey(dept)) return _cache[dept]!;
    final asset = await _findAssetForDept(dept);
    if (asset == null) {
      _cache[dept] = const [];
      return const [];
    }

    final raw = await rootBundle.loadString(asset);
    final decoded = jsonDecode(raw);

    final List list = decoded is List ? decoded : (decoded['data'] as List? ?? const []);
    final records = list
        .whereType<Map>()
        .map((m) => CityRecord.fromJson(m.cast<String, dynamic>()))
        .toList();

    _cache[dept] = records;
    return records;
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"['']"), "'")
      .replaceAll(RegExp(r"[^\p{Letter}\p{Number}\s-]+", unicode: true), ' ')
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();

  Future<List<CityRecord>> search(String query,
      {String? deptHint, int limit = 15}) async {
    final q = _norm(query);
    if (q.isEmpty) return const [];

    List<CityRecord> pool = const [];
    if (deptHint != null && deptHint.isNotEmpty) {
      pool = await loadDept(deptHint);
    } else {
      // si aucun dept n'est donné, on cherche dans ce qui est déjà en cache
      pool = _cache.values.expand((x) => x).toList();
    }

    final out = <CityRecord>[];
    for (final c in pool) {
      final n = _norm(c.name);
      if (n.startsWith(q) || n.contains(q)) {
        out.add(c);
        if (out.length >= limit) break;
      }
    }
    return out;
  }
}
