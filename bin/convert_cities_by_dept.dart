import 'dart:convert';
import 'dart:io';

/// Script de conversion des données de communes
/// Source : tools/communes_full.json
/// Sortie : assets/data/cities/cities_<dept>.json
///
/// Format de sortie attendu par CitySearch :
/// [
///   {
///     "name":   "Les Abymes",
///     "cp":     "97139",
///     "dept":   "971",
///     "region": "01"
///   },
///   ...
/// ]
Future<void> main() async {
  final rootDir = Directory.current.path;
  final sourceFile = File('$rootDir/tools/communes_full.json');

  if (!await sourceFile.exists()) {
    print('❌ Fichier tools/communes_full.json introuvable.');
    print('   Chemin cherché : ${sourceFile.path}');
    exit(1);
  }

  print('📥 Lecture de ${sourceFile.path} ...');
  final raw = await sourceFile.readAsString();
  print('   Taille : ${(raw.length / (1024 * 1024)).toStringAsFixed(2)} Mo');

  final decoded = jsonDecode(raw);

  if (decoded is! Map<String, dynamic>) {
    print('❌ Le JSON racine n\'est pas un objet Map.');
    exit(1);
  }

  // Selon l'inspection précédente :
  // root keys: metadata, colonnes, data
  final data = decoded['data'];
  if (data is! List) {
    print('❌ Clé "data" absente ou pas une liste.');
    exit(1);
  }

  print('   Nombre de lignes : ${data.length}');

  // Regroupement par département
  final Map<String, List<Map<String, String>>> byDept = {};

  for (final row in data) {
    if (row is! Map<String, dynamic>) continue;

    final name = _extractName(row);
    final cp = _extractPostalCode(row);
    final dept = _asString(row['dep_code']);
    final region = _asString(row['reg_code']);

    if (name.isEmpty || cp.isEmpty || dept.isEmpty || region.isEmpty) {
      continue; // on saute les lignes incomplètes
    }

    byDept.putIfAbsent(dept, () => []);
    byDept[dept]!.add({
      'name': name,
      'cp': cp,
      'dept': dept,
      'region': region,
    });
  }

  // Création du dossier de sortie
  final outDir = Directory('$rootDir/assets/data/cities');
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  // Écriture des fichiers par département
  for (final entry in byDept.entries) {
    final dept = entry.key;
    final cities = entry.value;

    // Tri par nom de ville pour un comportement stable
    cities.sort((a, b) => a['name']!.compareTo(b['name']!));

    final outFile = File('${outDir.path}/cities_$dept.json');
    final content = const JsonEncoder.withIndent('  ').convert(cities);
    await outFile.writeAsString(content);

    print('💾 ${outFile.path} → ${cities.length} communes');
  }

  print('✅ Conversion terminée !');
}

/// Récupère le nom de ville principal
String _extractName(Map<String, dynamic> row) {
  // On privilégie nom_standard
  final candidates = [
    row['nom_standard'],
    row['nom_sans_pronom'],
    row['nom_sans_accent'],
  ];

  for (final c in candidates) {
    final s = _asString(c);
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// Récupère un code postal
String _extractPostalCode(Map<String, dynamic> row) {
  final cp1 = _asString(row['code_postal']);
  if (cp1.isNotEmpty) return cp1;

  final cps = _asString(row['codes_postaux']);
  if (cps.isEmpty) return '';

  // Parfois plusieurs CP : on prend le premier (séparateurs possibles : espace, , ; |)
  final parts = cps.split(RegExp(r'[ ,;|]')).map((e) => e.trim()).toList();
  return parts.isNotEmpty ? parts.first : '';
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}
