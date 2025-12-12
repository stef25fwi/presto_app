import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CityEntry {
  final String name;
  final String dept;        // "75", "971", "2A", "987"...
  final List<String> cps;   // ["75001","75002",...]
  final String nameNorm;

  CityEntry({
    required this.name,
    required this.dept,
    required this.cps,
    required this.nameNorm,
  });

  factory CityEntry.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    final dept = (j['dept'] ?? '').toString();
    final cps = (j['cps'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return CityEntry(
      name: name,
      dept: dept,
      cps: cps,
      nameNorm: _normalize(name),
    );
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"['']"), "'")
      .replaceAll(RegExp(r"[^\p{Letter}\p{Number}\s-]+", unicode: true), ' ')
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
}

class CityRepoCompact {
  List<CityEntry>? _all;

  Future<void> init() async {
    if (_all != null) return;
    final raw = await rootBundle.loadString('assets/data/cities_compact.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _all = list.map(CityEntry.fromJson).toList(growable: false);
  }

  String? _cp5(String text) {
    final m = RegExp(r'\b(\d{5})\b').firstMatch(text);
    return m?.group(1);
  }

  /// CP -> dept candidates (Corse: 20xxx => 2A OU 2B)
  List<String> deptCandidatesFromCp(String cp5) {
    if (cp5.startsWith('97') || cp5.startsWith('98')) return [cp5.substring(0, 3)];
    if (cp5.startsWith('20')) return ['2A', '2B'];
    return [cp5.substring(0, 2)];
  }

  List<CityEntry> search(String query, {String? cpHint, int limit = 15}) {
    final all = _all ?? const <CityEntry>[];
    final q = CityEntry._normalize(query);
    if (q.isEmpty) return const [];

    final cp = cpHint != null ? _cp5(cpHint) : null;
    final deptFilter = cp != null ? deptCandidatesFromCp(cp) : null;

    final out = <CityEntry>[];
    for (final c in all) {
      if (deptFilter != null && !deptFilter.contains(c.dept)) continue;
      if (c.nameNorm.startsWith(q) || c.nameNorm.contains(q)) {
        out.add(c);
        if (out.length >= limit) break;
      }
    }
    return out;
  }
}
