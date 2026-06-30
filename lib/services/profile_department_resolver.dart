class ProfileDepartmentResolver {
  const ProfileDepartmentResolver._();

  static const Map<String, String> departmentLabels = {
    '01': 'Ain',
    '02': 'Aisne',
    '03': 'Allier',
    '04': 'Alpes-de-Haute-Provence',
    '05': 'Hautes-Alpes',
    '06': 'Alpes-Maritimes',
    '07': 'Ardèche',
    '08': 'Ardennes',
    '09': 'Ariège',
    '10': 'Aube',
    '11': 'Aude',
    '12': 'Aveyron',
    '13': 'Bouches-du-Rhône',
    '14': 'Calvados',
    '15': 'Cantal',
    '16': 'Charente',
    '17': 'Charente-Maritime',
    '18': 'Cher',
    '19': 'Corrèze',
    '2A': 'Corse-du-Sud',
    '2B': 'Haute-Corse',
    '21': 'Côte-d’Or',
    '22': 'Côtes-d’Armor',
    '23': 'Creuse',
    '24': 'Dordogne',
    '25': 'Doubs',
    '26': 'Drôme',
    '27': 'Eure',
    '28': 'Eure-et-Loir',
    '29': 'Finistère',
    '30': 'Gard',
    '31': 'Haute-Garonne',
    '32': 'Gers',
    '33': 'Gironde',
    '34': 'Hérault',
    '35': 'Ille-et-Vilaine',
    '36': 'Indre',
    '37': 'Indre-et-Loire',
    '38': 'Isère',
    '39': 'Jura',
    '40': 'Landes',
    '41': 'Loir-et-Cher',
    '42': 'Loire',
    '43': 'Haute-Loire',
    '44': 'Loire-Atlantique',
    '45': 'Loiret',
    '46': 'Lot',
    '47': 'Lot-et-Garonne',
    '48': 'Lozère',
    '49': 'Maine-et-Loire',
    '50': 'Manche',
    '51': 'Marne',
    '52': 'Haute-Marne',
    '53': 'Mayenne',
    '54': 'Meurthe-et-Moselle',
    '55': 'Meuse',
    '56': 'Morbihan',
    '57': 'Moselle',
    '58': 'Nièvre',
    '59': 'Nord',
    '60': 'Oise',
    '61': 'Orne',
    '62': 'Pas-de-Calais',
    '63': 'Puy-de-Dôme',
    '64': 'Pyrénées-Atlantiques',
    '65': 'Hautes-Pyrénées',
    '66': 'Pyrénées-Orientales',
    '67': 'Bas-Rhin',
    '68': 'Haut-Rhin',
    '69': 'Rhône',
    '70': 'Haute-Saône',
    '71': 'Saône-et-Loire',
    '72': 'Sarthe',
    '73': 'Savoie',
    '74': 'Haute-Savoie',
    '75': 'Paris',
    '76': 'Seine-Maritime',
    '77': 'Seine-et-Marne',
    '78': 'Yvelines',
    '79': 'Deux-Sèvres',
    '80': 'Somme',
    '81': 'Tarn',
    '82': 'Tarn-et-Garonne',
    '83': 'Var',
    '84': 'Vaucluse',
    '85': 'Vendée',
    '86': 'Vienne',
    '87': 'Haute-Vienne',
    '88': 'Vosges',
    '89': 'Yonne',
    '90': 'Territoire de Belfort',
    '91': 'Essonne',
    '92': 'Hauts-de-Seine',
    '93': 'Seine-Saint-Denis',
    '94': 'Val-de-Marne',
    '95': 'Val-d’Oise',
    '971': 'Guadeloupe',
    '972': 'Martinique',
    '973': 'Guyane',
    '974': 'La Réunion',
    '976': 'Mayotte',
  };

  static const Map<String, String> _cityDepartmentHints = {
    'baie-mahault': '971',
    'baie mahault': '971',
    'les abymes': '971',
    'abymes': '971',
    'pointe-a-pitre': '971',
    'pointe a pitre': '971',
    'point a pitre': '971',
    'petit-bourg': '971',
    'petit bourg': '971',
    'goyave': '971',
    'saint-francois': '971',
    'saint francois': '971',
    'sainte-anne': '971',
    'sainte anne': '971',
    'basse-terre': '971',
    'basse terre': '971',
    'le gosier': '971',
    'gosier': '971',
    'morne-a-l-eau': '971',
    'morne a l eau': '971',
    'lamentin': '971',
    'capesterre-belle-eau': '971',
    'capesterre belle eau': '971',
    'sainte-rose': '971',
    'sainte rose': '971',
    'trois-rivieres': '971',
    'trois rivieres': '971',
    'vieux-habitants': '971',
    'vieux habitants': '971',
    'bouillante': '971',
    'deshaies': '971',
    'terre-de-haut': '971',
    'terre de haut': '971',
    'terre-de-bas': '971',
    'terre de bas': '971',
    'marie-galante': '971',
    'grand-bourg': '971',
    'grand bourg': '971',
  };

  static String? normalizeDepartmentCode(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    final upper = raw.toUpperCase();

    if (upper == '2A' || upper == '2B') return upper;

    final digits = upper.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (digits.length >= 3 && digits.startsWith('97')) {
      return digits.substring(0, 3);
    }

    if (digits.length >= 2) {
      return digits.substring(0, 2).padLeft(2, '0');
    }

    return digits.padLeft(2, '0');
  }

  static String? departmentCodeFromPostalCode(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    final clean = raw.replaceAll(RegExp(r'[^0-9ABab]'), '').toUpperCase();
    if (clean.length < 2) return null;

    if (clean.startsWith('97') && clean.length >= 3) {
      return clean.substring(0, 3);
    }

    if (clean.startsWith('20') && clean.length >= 2) {
      return '2A';
    }

    return clean.substring(0, 2);
  }

  static String? departmentCodeFromLabel(Object? value) {
    final raw = _normalizeCity(value?.toString() ?? '');
    if (raw.isEmpty) return null;

    for (final entry in departmentLabels.entries) {
      if (_normalizeCity(entry.value) == raw) {
        return entry.key;
      }
    }

    return normalizeDepartmentCode(value);
  }

  static String? departmentCodeFromCity(Object? value) {
    final raw = _normalizeCity(value?.toString() ?? '');
    if (raw.isEmpty) return null;

    if (_cityDepartmentHints.containsKey(raw)) {
      return _cityDepartmentHints[raw];
    }

    final embeddedPostal = RegExp(r'\b(97[1-6]|[0-9]{2})[0-9]{3}\b')
        .firstMatch(value?.toString() ?? '');
    if (embeddedPostal != null) {
      return departmentCodeFromPostalCode(embeddedPostal.group(0));
    }

    return null;
  }

  static String? resolveDepartmentCode({
    Object? city,
    Object? postalCode,
    Object? departmentCode,
    Object? departmentLabel,
  }) {
    return normalizeDepartmentCode(departmentCode) ??
        departmentCodeFromLabel(departmentLabel) ??
        departmentCodeFromPostalCode(postalCode) ??
        departmentCodeFromCity(city);
  }

  static String departmentDisplayName(String code) {
    final normalized = normalizeDepartmentCode(code) ?? code;
    final label = departmentLabels[normalized];
    if (label == null || label.isEmpty) return normalized;
    return '$normalized - $label';
  }

  static String _normalizeCity(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
