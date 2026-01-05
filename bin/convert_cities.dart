// fichier: bin/convert_cities.dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // 1. Chemin vers le gros JSON téléchargé depuis data.gouv
  final inputFile = File('communes_full.json'); // adapte le nom

  // 2. Chemin du JSON simplifié que tu vas utiliser dans Flutter
  final outputFile = File('cities_fr.json');

  print('Lecture du fichier ${inputFile.path}...');
  final raw = await inputFile.readAsString();

  // Le JSON de data.gouv est une LISTE d'objets
  final List<dynamic> list = json.decode(raw);

  // On construit une map: nom_standard -> code_postal
  final Map<String, String> cityMap = {};

  for (final item in list) {
    if (item is Map<String, dynamic>) {
      final String? name = item['nom_standard']?.toString();
      final String? cp = item['code_postal']?.toString();

      if (name != null && cp != null && name.isNotEmpty && cp.isNotEmpty) {
        cityMap[name] = cp;
      }
    }
  }

  print('Nombre de communes retenues : ${cityMap.length}');

  // 3. On écrit le JSON final, joli et compact
  final encoder = const JsonEncoder.withIndent('  ');
  await outputFile.writeAsString(encoder.convert(cityMap));

  print('Fichier généré : ${outputFile.path}');
}
