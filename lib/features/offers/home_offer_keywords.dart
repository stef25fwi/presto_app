/// Construit les mots-clés de recherche de l'accueil à partir des offres déjà
/// chargées, sans lecture Firestore supplémentaire.
List<String> buildHomeOfferKeywords(
  Iterable<Map<String, dynamic>> offers, {
  int minimumLength = 4,
  int maximumKeywords = 80,
}) {
  if (minimumLength < 1) {
    throw ArgumentError.value(
      minimumLength,
      'minimumLength',
      'La longueur minimale doit être positive',
    );
  }
  if (maximumKeywords < 1) {
    throw ArgumentError.value(
      maximumKeywords,
      'maximumKeywords',
      'Le nombre maximal doit être positif',
    );
  }

  final words = <String>{};
  final numericPattern = RegExp(r'[0-9]');
  final separatorPattern = RegExp(r'\s+');

  for (final offer in offers) {
    final title = (offer['title'] ?? '').toString().toLowerCase();
    final description = (offer['description'] ?? '').toString().toLowerCase();
    final combined = '$title $description';

    for (final rawWord in combined.split(separatorPattern)) {
      final word =
          rawWord.replaceAll(RegExp(r'^[^a-zà-ÿ]+|[^a-zà-ÿ]+$'), '').trim();
      if (word.length < minimumLength || numericPattern.hasMatch(word)) {
        continue;
      }
      words.add(word);
    }
  }

  final sorted = words.toList(growable: false)..sort();
  return sorted.take(maximumKeywords).toList(growable: false);
}
