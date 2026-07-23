import '../constants.dart';

const Map<String, String> _offerCategoryIdsByLabel = <String, String>{
  'Restauration / Extra': 'restauration-extra',
  'Bricolage / Travaux': 'bricolage-travaux',
  'Aide à domicile': 'aide-a-domicile',
  'Garde d\'enfants': 'garde-d-enfants',
  'Événementiel / DJ': 'evenementiel-dj',
  'Cours & soutien': 'cours-soutien',
  'Jardinage': 'jardinage',
  'Peinture': 'peinture',
  'Main-d\'œuvre': 'main-d-oeuvre',
  'Autre': 'autre',
};

String offerSlugify(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('œ', 'oe')
      .replaceAll(RegExp(r"[/\-'’']"), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(' ', '-');
}

String normalizeOfferText(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('œ', 'oe')
      .replaceAll(RegExp(r"[/\-'’']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? canonicalizeOfferCategory(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;

  final normalized = normalizeOfferText(raw);

  const aliases = <String, String>{
    'bricolage': 'Bricolage / Travaux',
    'bricolage travaux': 'Bricolage / Travaux',
    'travaux': 'Bricolage / Travaux',
    'menage': 'Aide à domicile',
    'aide menagere': 'Aide à domicile',
    'aide menagere a domicile': 'Aide à domicile',
    'aide a domicile': 'Aide à domicile',
    'aide domicile': 'Aide à domicile',
    'baby sitting': 'Garde d\'enfants',
    'babysitting': 'Garde d\'enfants',
    'baby sitter': 'Garde d\'enfants',
    'garde enfants': 'Garde d\'enfants',
    'garde d enfants': 'Garde d\'enfants',
    'restauration': 'Restauration / Extra',
    'extra': 'Restauration / Extra',
    'dj sono': 'Événementiel / DJ',
    'dj': 'Événementiel / DJ',
    'sono': 'Événementiel / DJ',
    'evenementiel dj': 'Événementiel / DJ',
    'evenementiel': 'Événementiel / DJ',
    'informatique': 'Cours & soutien',
    'cours soutien': 'Cours & soutien',
    'cours et soutien': 'Cours & soutien',
    'main d oeuvre': 'Main-d\'œuvre',
    'main oeuvre': 'Main-d\'œuvre',
    'autres': 'Autre',
  };

  if (aliases.containsKey(normalized)) {
    return aliases[normalized];
  }

  String? best;
  var bestScore = -1;
  for (final category in kCategories) {
    final candidate = normalizeOfferText(category);
    var score = -1;
    if (candidate == normalized) {
      score = 10000;
    } else if (candidate.contains(normalized) && normalized.length >= 2) {
      score = 5000 + normalized.length;
    } else if (normalized.contains(candidate) && candidate.length >= 2) {
      score = 3000 + candidate.length;
    }
    if (score > bestScore) {
      bestScore = score;
      best = category;
    }
  }

  return bestScore > 0 ? best : raw;
}

String? resolveOfferCategoryId(String? input) {
  final canonical = canonicalizeOfferCategory(input);
  if (canonical == null || canonical.trim().isEmpty) {
    return null;
  }

  final directMatch = _offerCategoryIdsByLabel[canonical];
  if (directMatch != null) {
    return directMatch;
  }

  return offerSlugify(canonical);
}

String? departmentFromPostalCode(String? postalCode) {
  final cp = (postalCode ?? '').trim();
  if (cp.length < 2) return null;
  if (cp.startsWith('97') || cp.startsWith('98')) {
    return cp.length >= 3 ? cp.substring(0, 3) : cp;
  }
  return cp.substring(0, 2);
}

double? budgetValueFromDynamic(dynamic rawBudget) {
  if (rawBudget == null) return null;
  if (rawBudget is num) return rawBudget.toDouble();

  final normalized = rawBudget
      .toString()
      .trim()
      .replaceAll('€', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

Map<String, dynamic> buildOfferIndexFields({
  required String? category,
  required String? city,
  required String? postalCode,
  dynamic budget,
  String? status,
  bool? isActive,
}) {
  final canonicalCategory = canonicalizeOfferCategory(category) ?? 'Autre';
  final safeCity = (city ?? '').trim();
  final safePostalCode = (postalCode ?? '').trim();
  final categoryId = resolveOfferCategoryId(canonicalCategory)!;
  final cityId = safeCity.isNotEmpty && safePostalCode.length >= 3
      ? '${safePostalCode}_${offerSlugify(safeCity)}'
      : null;

  final active =
      isActive ?? ((status ?? 'active').trim().toLowerCase() == 'active');
  final budgetValue = budgetValueFromDynamic(budget);
  final dept = departmentFromPostalCode(safePostalCode);

  return {
    'category': canonicalCategory,
    'categoryId': categoryId,
    'city': safeCity,
    'location': safeCity,
    'cp': safePostalCode.isEmpty ? null : safePostalCode,
    'postalCode': safePostalCode.isEmpty ? null : safePostalCode,
    'cityId': cityId,
    'cityCategoryKey': cityId == null ? null : '${cityId}_$categoryId',
    'dept': dept,
    'budgetValue': budgetValue,
    'isActive': active,
    'isPublished': active,
    'status': active ? 'active' : (status ?? 'inactive'),
    'visibility': {
      'isPublic': active,
    },
  };
}
