part of '../pricing_calculator_page.dart';

// ---------------------------
// LOCAL HISTORY + PDF EXPORT
// ---------------------------
class PricingProjectRecord {
  final String id;
  final DateTime createdAt;
  final String name;
  final PricingMode mode;
  final PricingInput input;
  final PricingResult result;
  final double marketLow;
  final double marketMid;
  final double marketHigh;
  final int volumePrudent;
  final int volumeHaut;

  const PricingProjectRecord({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.mode,
    required this.input,
    required this.result,
    required this.marketLow,
    required this.marketMid,
    required this.marketHigh,
    required this.volumePrudent,
    required this.volumeHaut,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        'mode': mode.name,
        'input': input.toJson(),
        'result': result.toJson(),
        'marketLow': marketLow,
        'marketMid': marketMid,
        'marketHigh': marketHigh,
        'volumePrudent': volumePrudent,
        'volumeHaut': volumeHaut,
      };

  factory PricingProjectRecord.fromJson(Map<String, dynamic> json) {
    return PricingProjectRecord(
      id: json['id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      name: json['name']?.toString() ?? 'Calcul sans nom',
      mode: json['mode'] == PricingMode.expert.name
          ? PricingMode.expert
          : PricingMode.standard,
      input: PricingInput.fromJson(
        Map<String, dynamic>.from(json['input'] as Map? ?? const {}),
      ),
      result: PricingResult.fromJson(
        Map<String, dynamic>.from(json['result'] as Map? ?? const {}),
      ),
      marketLow: _jsonDouble(json['marketLow']),
      marketMid: _jsonDouble(json['marketMid']),
      marketHigh: _jsonDouble(json['marketHigh']),
      volumePrudent: math.max(_jsonInt(json['volumePrudent']), 1),
      volumeHaut: math.max(_jsonInt(json['volumeHaut']), 1),
    );
  }
}

class PricingProjectStorage {
  static const _storageKey = 'ilipresto_pricing_projects_v2';
  static const _maxProjects = 30;

  static Future<List<PricingProjectRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <PricingProjectRecord>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PricingProjectRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => PricingProjectRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return <PricingProjectRecord>[];
    }
  }

  static Future<void> save(PricingProjectRecord record) async {
    final projects = await load();
    projects.removeWhere((item) => item.id == record.id);
    projects.insert(0, record);
    if (projects.length > _maxProjects) {
      projects.removeRange(_maxProjects, projects.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(projects.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> delete(String id) async {
    final projects = await load();
    projects.removeWhere((item) => item.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(projects.map((item) => item.toJson()).toList()),
    );
  }
}

