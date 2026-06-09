class RegionNormalizer {
  const RegionNormalizer._();

  static String normalize(String value) {
    final input = value.trim().toLowerCase();

    final normalized = input
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('œ', 'oe')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return _aliases[normalized] ?? normalized;
  }

  static String regionCodeFromDepartment(String departmentCode) {
    final code = departmentCode.trim().toUpperCase();

    for (final entry in _departmentToRegion.entries) {
      if (entry.value.contains(code)) {
        return entry.key;
      }
    }

    return '';
  }

  static const Map<String, String> _aliases = {
    'idf': 'ile_de_france',
    'ile_de_france': 'ile_de_france',
    'paca': 'provence_alpes_cote_d_azur',
    'provence_alpes_cote_d_azur': 'provence_alpes_cote_d_azur',
    'la_reunion': 'reunion',
    'reunion': 'reunion',
    'guadeloupe': 'guadeloupe',
    'martinique': 'martinique',
    'guyane': 'guyane',
    'mayotte': 'mayotte',
  };

  static const Map<String, List<String>> _departmentToRegion = {
    'auvergne_rhone_alpes': [
      '01',
      '03',
      '07',
      '15',
      '26',
      '38',
      '42',
      '43',
      '63',
      '69',
      '73',
      '74',
    ],
    'bourgogne_franche_comte': [
      '21',
      '25',
      '39',
      '58',
      '70',
      '71',
      '89',
      '90',
    ],
    'bretagne': ['22', '29', '35', '56'],
    'centre_val_de_loire': ['18', '28', '36', '37', '41', '45'],
    'corse': ['2A', '2B'],
    'grand_est': ['08', '10', '51', '52', '54', '55', '57', '67', '68', '88'],
    'hauts_de_france': ['02', '59', '60', '62', '80'],
    'ile_de_france': ['75', '77', '78', '91', '92', '93', '94', '95'],
    'normandie': ['14', '27', '50', '61', '76'],
    'nouvelle_aquitaine': [
      '16',
      '17',
      '19',
      '23',
      '24',
      '33',
      '40',
      '47',
      '64',
      '79',
      '86',
      '87',
    ],
    'occitanie': [
      '09',
      '11',
      '12',
      '30',
      '31',
      '32',
      '34',
      '46',
      '48',
      '65',
      '66',
      '81',
      '82',
    ],
    'pays_de_la_loire': ['44', '49', '53', '72', '85'],
    'provence_alpes_cote_d_azur': ['04', '05', '06', '13', '83', '84'],
    'guadeloupe': ['971'],
    'martinique': ['972'],
    'guyane': ['973'],
    'reunion': ['974'],
    'mayotte': ['976'],
  };
}
