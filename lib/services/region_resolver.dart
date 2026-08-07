String? inferRegionFromPostalCode(String postalCode) {
  final cp = postalCode.trim();
  if (cp.length < 2) return null;

  if (cp.length >= 3 && cp.startsWith('97')) {
    switch (cp.substring(0, 3)) {
      case '971':
        return 'Guadeloupe';
      case '972':
        return 'Martinique';
      case '973':
        return 'Guyane';
      case '974':
        return 'La Réunion';
      case '976':
        return 'Mayotte';
    }
  }

  if (cp.startsWith('20')) return 'Corse';

  final two = int.tryParse(cp.substring(0, 2));
  if (two == null) return null;

  if (<int>{1, 3, 7, 15, 26, 38, 42, 43, 63, 69, 73, 74}.contains(two)) {
    return 'Auvergne-Rhône-Alpes';
  }
  if (<int>{21, 25, 39, 58, 70, 71, 89, 90}.contains(two)) {
    return 'Bourgogne-Franche-Comté';
  }
  if (<int>{22, 29, 35, 56}.contains(two)) return 'Bretagne';
  if (<int>{18, 28, 36, 37, 41, 45}.contains(two)) {
    return 'Centre-Val de Loire';
  }
  if (<int>{8, 10, 51, 52, 54, 55, 57, 67, 68, 88}.contains(two)) {
    return 'Grand Est';
  }
  if (<int>{2, 59, 60, 62, 80}.contains(two)) return 'Hauts-de-France';
  if (<int>{75, 77, 78, 91, 92, 93, 94, 95}.contains(two)) {
    return 'Île-de-France';
  }
  if (<int>{14, 27, 50, 61, 76}.contains(two)) return 'Normandie';
  if (<int>{16, 17, 19, 23, 24, 33, 40, 47, 64, 79, 86, 87}.contains(two)) {
    return 'Nouvelle-Aquitaine';
  }
  if (<int>{9, 11, 12, 30, 31, 32, 34, 46, 48, 65, 66, 81, 82}.contains(two)) {
    return 'Occitanie';
  }
  if (<int>{44, 49, 53, 72, 85}.contains(two)) return 'Pays de la Loire';
  if (<int>{4, 5, 6, 13, 83, 84}.contains(two)) {
    return 'Provence-Alpes-Côte d\'Azur';
  }
  return null;
}
