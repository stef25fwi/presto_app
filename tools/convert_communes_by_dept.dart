import 'dart:convert';
import 'dart:io';

const String kInputFile = 'communes_full.json';
const String kOutputDir = 'cities_by_dept';

/// Extracts one postal code as a String (5 digits) from raw value.
String? extractFirstPostal(dynamic raw) {
  if (raw == null) return null;

  // If already a String: may contain one or several CP separated by space, comma or semicolon.
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final parts = text.split(RegExp(r'[;,\s]+'));
    for (final p in parts) {
      final cp = p.trim();
      if (RegExp(r'^\d{5}$').hasMatch(cp)) {
        return cp;
      }
    }
    return null;
  }

  // If list of codes
  if (raw is List) {
    for (final item in raw) {
      final cp = extractFirstPostal(item);
      if (cp != null) return cp;
    }
    return null;
  }

  // Fallback: try toString
  return extractFirstPostal(raw.toString());
}

Future<void> main() async {
  final inputFile = File(kInputFile);
  if (!await inputFile.exists()) {
    print('ERROR: File $kInputFile not found in ${Directory.current.path}');
    return;
  }

  print('Reading $kInputFile ...');
  final raw = await inputFile.readAsString();
  print('Size: ${(raw.length / (1024 * 1024)).toStringAsFixed(2)} MB');

  dynamic decoded;
  try {
    decoded = json.decode(raw);
  } catch (e) {
    print('JSON parse error: $e');
    return;
  }

  if (decoded is! Map<String, dynamic>) {
    print('Root is not a JSON object. Type: ${decoded.runtimeType}');
    return;
  }

  final map = decoded as Map<String, dynamic>;
  print('Root keys: ${map.keys.join(', ')}');

  final dynamic data = map['data'];
  if (data is! List) {
    print('Key "data" is not a List. Type: ${data.runtimeType}');
    return;
  }

  print('Rows count: ${data.length}');

  // dept -> { cityName -> postalCode }
  final Map<String, Map<String, String>> byDept =
      <String, Map<String, String>>{};

  int processed = 0;
  for (final rowDyn in data) {
    if (rowDyn is! Map<String, dynamic>) continue;
    final row = rowDyn;

    final String? dept = row['dep_code']?.toString().trim();
    final String? name = row['nom_standard']?.toString().trim();
    final dynamic cpRaw = row.containsKey('code_postal')
        ? row['code_postal']
        : row['codes_postaux'];

    if (dept == null || dept.isEmpty) continue;
    if (name == null || name.isEmpty) continue;

    final String? cp = extractFirstPostal(cpRaw);
    if (cp == null) continue;

    byDept.putIfAbsent(dept, () => <String, String>{});
    byDept[dept]![name] = cp;
    processed++;
  }

  print('Processed rows with valid dept/city/cp: $processed');
  print('Departments found: ${byDept.keys.length}');

  final outDir = Directory(kOutputDir);
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  final encoder = const JsonEncoder.withIndent('  ');

  for (final entry in byDept.entries) {
    final dept = entry.key;
    final citiesMap = entry.value;

    // sort by city name for nicer files
    final sortedKeys = citiesMap.keys.toList()..sort();
    final Map<String, String> sortedMap = {
      for (final k in sortedKeys) k: citiesMap[k]!,
    };

    final outFile = File('${outDir.path}/cities_$dept.json');
    await outFile.writeAsString(encoder.convert(sortedMap));
    print(
        'Written dept $dept -> ${sortedMap.length} cities -> ${outFile.path}');
  }

  print('DONE.');
}
