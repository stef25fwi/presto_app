import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'entrepreneur_pricing_models.dart';

class EntrepreneurPricingRecord {
  const EntrepreneurPricingRecord({
    required this.id,
    required this.createdAt,
    required this.draft,
    required this.calculation,
  });

  final String id;
  final DateTime createdAt;
  final EntrepreneurPricingDraft draft;
  final EntrepreneurPricingCalculation calculation;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'draft': draft.toJson(),
        'calculation': calculation.toJson(),
      };

  factory EntrepreneurPricingRecord.fromJson(Map<String, dynamic> json) {
    return EntrepreneurPricingRecord(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      draft: EntrepreneurPricingDraft.fromJson(
        Map<String, dynamic>.from(json['draft'] as Map? ?? const {}),
      ),
      calculation: EntrepreneurPricingCalculation.fromJson(
        Map<String, dynamic>.from(json['calculation'] as Map? ?? const {}),
      ),
    );
  }
}

class EntrepreneurPricingStorage {
  const EntrepreneurPricingStorage._();

  static const String storageKey = 'ilipresto_pricing_projects_v3';
  static const int maxProjects = 30;
  static const int schemaVersion = 3;

  static Future<List<EntrepreneurPricingRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <EntrepreneurPricingRecord>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <EntrepreneurPricingRecord>[];

      final records = <EntrepreneurPricingRecord>[];
      for (final item in decoded.whereType<Map>()) {
        final envelope = Map<String, dynamic>.from(item);
        final payload = envelope['payload'];
        final checksum = envelope['checksum']?.toString() ?? '';
        final version = pricingJsonInt(envelope['version']);
        if (version != schemaVersion || payload is! Map) continue;

        final normalizedPayload = Map<String, dynamic>.from(payload);
        final encodedPayload = jsonEncode(normalizedPayload);
        if (_checksum(encodedPayload) != checksum) continue;

        final record = EntrepreneurPricingRecord.fromJson(normalizedPayload);
        if (record.id.isNotEmpty) records.add(record);
      }

      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (_) {
      return <EntrepreneurPricingRecord>[];
    }
  }

  static Future<void> save(EntrepreneurPricingRecord record) async {
    final records = await load();
    records.removeWhere((item) => item.id == record.id);
    records.insert(0, record);
    if (records.length > maxProjects) {
      records.removeRange(maxProjects, records.length);
    }

    final encoded = jsonEncode(records.map(_envelopeFor).toList());
    final prefs = await SharedPreferences.getInstance();
    final wrote = await prefs.setString(storageKey, encoded);
    if (!wrote) {
      throw StateError('Échec d’écriture du calcul tarifaire.');
    }

    final reloaded = await load();
    final verified = reloaded.any(
      (item) =>
          item.id == record.id &&
          item.draft.toJson().toString() == record.draft.toJson().toString() &&
          item.calculation.toJson().toString() ==
              record.calculation.toJson().toString(),
    );
    if (!verified) {
      throw StateError('La sauvegarde du calcul n’a pas pu être vérifiée.');
    }
  }

  static Future<void> delete(String id) async {
    final records = await load();
    records.removeWhere((item) => item.id == id);

    final prefs = await SharedPreferences.getInstance();
    final wrote = await prefs.setString(
      storageKey,
      jsonEncode(records.map(_envelopeFor).toList()),
    );
    if (!wrote) {
      throw StateError('Échec de suppression du calcul tarifaire.');
    }

    final reloaded = await load();
    if (reloaded.any((item) => item.id == id)) {
      throw StateError('La suppression du calcul n’a pas pu être vérifiée.');
    }
  }

  static Map<String, dynamic> _envelopeFor(EntrepreneurPricingRecord record) {
    final payload = record.toJson();
    final encodedPayload = jsonEncode(payload);
    return {
      'version': schemaVersion,
      'checksum': _checksum(encodedPayload),
      'payload': payload,
    };
  }

  static String _checksum(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}