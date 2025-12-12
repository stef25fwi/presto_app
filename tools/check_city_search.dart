// tools/check_city_search.dart
//
// Outil de vérification des communes pour CityPostalService
// dart run tools/check_city_search.dart

import 'dart:convert';
import 'dart:io';

/// Même liste de départements que pour tes fichiers cities_XX.json
const List<String> kDeptCodes = <String>[
  "01","02","03","04","05","06","07","08","09",
  "10","11","12","13","14","15","16","17","18","19",
  "21","22","23","24","25","26","27","28","29",
  "2A","2B",
  "30","31","32","33","34","35","36","37","38","39",
  "40","41","42","43","44","45","46","47","48","49",
  "50","51","52","53","54","55","56","57","58","59",
  "60","61","62","63","64","65","66","67","68","69",
  "70","71","72","73","74","75","76","77","78","79",
  "80","81","82","83","84","85","86","87","88","89","90",
  "91","92","93","94","95",
  "971","972","973","974","976",
];

/// Normalisation identique à CityPostalService._normalize
String normalize(String input) {
  String s = input.toLowerCase();

  const Map<String, String> rep = <String, String>{
    "à": "a",
    "â": "a",
    "ä": "a",
    "á": "a",
    "ã": "a",
    "å": "a",
    "ç": "c",
    "é": "e",
    "è": "e",
    "ê": "e",
    "ë": "e",
    "í": "i",
    "ì": "i",
    "î": "i",
    "ï": "i",
    "ñ": "n",
    "ó": "o",
    "ò": "o",
    "ô": "o",
    "ö": "o",
    "õ": "o",
    "ú": "u",
    "ù": "u",
    "û": "u",
    "ü": "u",
    "ÿ": "y",
  };

  rep.forEach((String k, String v) {
    s = s.replaceAll(k, v);
  });

  s = s
      .replaceAll("-", "")
      .replaceAll(" ", "")
      .replaceAll("'", "")
      .replaceAll("'", "");

  return s;
}

String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

List<String> searchCities(
  Map<String, String> cityToCp,
  Map<String, String> cityNorm,
  String query, {
  int maxResults = 15,
}) {
  final String q = query.toLowerCase().trim();
  if (q.isEmpty) return <String>[];

  final String qNorm = normalize(q);
  final String qDigits = digitsOnly(q);

  final List<String> matches = <String>[];

  for (final MapEntry<String, String> entry in cityToCp.entries) {
    final String cityLower = entry.key; // ex: "trois rivieres"
    final String cpRaw = entry.value;   // ex: "97114" ou "97114;97190"
    final String norm = cityNorm[cityLower] ?? normalize(cityLower);
    final String cpDigits = digitsOnly(cpRaw); // ex: "97114" ou "9711497190"

    // 🔍 Match par nom (avec ou sans accents / tirets)
    final bool matchByName =
        cityLower.contains(q) || norm.contains(qNorm) || norm == qNorm;

    // 🔍 Match par code postal (on ne garde que les chiffres)
    final bool matchByCp =
        qDigits.isNotEmpty && cpDigits.startsWith(qDigits);

    if (matchByName || matchByCp) {
      final String display = cityLower.isEmpty
          ? cityLower
          : '${cityLower[0].toUpperCase()}${cityLower.substring(1)}';
      matches.add(display);

      if (matches.length >= maxResults) break;
    }
  }

  // Dé-duplication
  final Set<String> seen = <String>{};
  final List<String> dedup = <String>[];
  for (final String m in matches) {
    final String k = m.toLowerCase();
    if (!seen.contains(k)) {
      seen.add(k);
      dedup.add(m);
    }
  }

  return dedup;
}

Future<void> main() async {
  final Map<String, String> cityToCp = <String, String>{};
  final Map<String, String> cityNorm = <String, String>{};
  final Map<String, List<String>> cpToCities = <String, List<String>>{};

  int totalCities = 0;

  // 1) Charger tous les fichiers cities_xxx.json
  for (final String dept in kDeptCodes) {
    final String path = "assets/data/cities/cities_$dept.json";
    final file = File(path);
    if (!file.existsSync()) {
      print("⚠️  Fichier manquant (ignoré) : $path");
      continue;
    }

    final String data = file.readAsStringSync();
    final Map<String, dynamic> jsonMap =
        json.decode(data) as Map<String, dynamic>;

    int localCount = 0;

    jsonMap.forEach((dynamic k, dynamic v) {
      final String cityOriginal = k.toString().trim();
      final String cp = v.toString().trim();
      if (cityOriginal.isEmpty || cp.isEmpty) return;

      final String lower = cityOriginal.toLowerCase();
      final String norm = normalize(lower);

      cityToCp[lower] = cp;
      cityNorm[lower] = norm;

      cpToCities.putIfAbsent(cp, () => <String>[]);
      if (!cpToCities[cp]!.contains(cityOriginal)) {
        cpToCities[cp]!.add(cityOriginal);
      }

      localCount++;
    });

    print("📥 $path → $localCount communes chargées");
    totalCities += localCount;
  }

  print("========================================");
  print("TOTAL COMMUNES CHARGÉES : $totalCities");
  print("========================================");

  // 2) Vérifications
  final List<String> citiesBadByName = <String>[];
  final List<String> cpBad = <String>[];

  // 2a) chaque ville doit être retrouvée par son nom
  cityToCp.forEach((String cityLower, String cp) {
    final String display =
        cityLower.isEmpty ? cityLower : cityLower[0].toUpperCase() + cityLower.substring(1);

    final List<String> results =
        searchCities(cityToCp, cityNorm, display, maxResults: 1000);

    final bool found = results.any(
      (String r) => r.toLowerCase() == cityLower,
    );

    if (!found) {
      citiesBadByName.add("$display ($cp)");
    }
  });

  // 2b) chaque CP doit retourner au moins une ville
  cpToCities.forEach((String cp, List<String> cities) {
    final List<String> results =
        searchCities(cityToCp, cityNorm, cp, maxResults: 1000);
    if (results.isEmpty) {
      cpBad.add(cp);
    }
  });

  print("");
  print("===== RÉSULTATS DES VÉRIFICATIONS =====");
  print("");

  if (citiesBadByName.isEmpty) {
    print("✅ Toutes les villes sont retrouvées par recherche sur leur nom.");
  } else {
    print("❌ Villes non retrouvées via recherche par nom (${citiesBadByName.length}) :");
    for (final String line in citiesBadByName.take(200)) {
      print("   - $line");
    }
    if (citiesBadByName.length > 200) {
      print("   ... (${citiesBadByName.length - 200} de plus)");
    }
  }

  print("");

  if (cpBad.isEmpty) {
    print("✅ Tous les codes postaux retournent au moins une ville.");
  } else {
    print("❌ Codes postaux sans résultat de recherche (${cpBad.length}) :");
    print(cpBad.take(200).join(", "));
  }

  print("");
  print("===== FIN DU CHECK =====");
}
