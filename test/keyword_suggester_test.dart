import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/keyword_suggester.dart';

const _items = <SuggestionItem>[
  SuggestionItem(
    label: 'Pâtisserie artisanale',
    keywords: <String>['gâteau', 'pâtisserie', 'dessert'],
    tags: <String>['food', 'artisanat'],
    regions: <String>['Guadeloupe'],
    situations: <String>['Sans emploi'],
    weight: 40,
    popularity: 90,
  ),
  SuggestionItem(
    label: 'Livraison de colis',
    keywords: <String>['livraison', 'coursier', 'transport'],
    tags: <String>['logistique'],
    regions: <String>['Martinique'],
    popularity: 70,
  ),
  SuggestionItem(
    label: 'Nettoyage à domicile',
    keywords: <String>['ménage', 'nettoyage', 'entretien'],
    popularity: 80,
  ),
  SuggestionItem(
    label: 'Création de site vitrine',
    keywords: <String>['site', 'web', 'vitrine'],
    tags: <String>['internet'],
    popularity: 60,
  ),
  SuggestionItem(
    label: 'Cours de coiffure',
    keywords: <String>['coiffure', 'tresses', 'barbier'],
    popularity: 50,
  ),
];

void main() {
  test('normalizes accents punctuation apostrophes and whitespace', () {
    expect(
      KeywordSuggester.normalize("  Création-d’un GÂTEAU !!!  "),
      'creation d un gateau',
    );
    expect(KeywordSuggester.normalize('Àççêñt ÿ'), 'accent y');
    expect(KeywordSuggester.normalize(''), '');
  });

  test('tokenizes while removing stopwords and applying light stemming', () {
    expect(
      KeywordSuggester.tokenize('Je veux créer des livraisons rapides'),
      containsAll(<String>['veux', 'livraison', 'rapide']),
    );
    expect(KeywordSuggester.tokenize('le la des projet entreprise'), isEmpty);
    expect(KeywordSuggester.tokenize('abc'), <String>['abc']);
    expect(KeywordSuggester.tokenize('nettoyer'), <String>['nettoy']);
  });

  test('computes exact and fuzzy similarities', () {
    expect(KeywordSuggester.similarity('gateau', 'gateau'), 1);
    expect(KeywordSuggester.similarity('', 'gateau'), 0);
    expect(KeywordSuggester.similarity('gateau', ''), 0);
    expect(KeywordSuggester.similarity('gateu', 'gateau'), greaterThan(0.8));
    expect(KeywordSuggester.similarity('abc', 'xyz'), 0);
  });

  test('suggestion item exposes normalized projections', () {
    const item = SuggestionItem(
      label: 'Ménage-Pro',
      keywords: <String>['Nettoyage', 'Propreté'],
      tags: <String>['Service à domicile'],
    );
    expect(item.normLabel, 'menage pro');
    expect(item.normKeywords, <String>['nettoyage', 'proprete']);
    expect(item.normTags, <String>['service a domicile']);
  });

  test('ranks synonym, prefix, bigram and region matches', () {
    final results = KeywordSuggester.compute(
      query: 'vente gateau',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
      limit: 3,
    );

    expect(results, isNotEmpty);
    expect(results.first.label, 'Pâtisserie artisanale');
    expect(results.length, lessThanOrEqualTo(3));
  });

  test('supports typo fuzzy matching and contains matching', () {
    final typo = KeywordSuggester.compute(
      query: 'patiseri',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
    );
    expect(typo.first.label, 'Pâtisserie artisanale');

    final contains = KeywordSuggester.compute(
      query: 'domicile',
      items: _items,
    );
    expect(contains.first.label, 'Nettoyage à domicile');
  });

  test('applies incompatible region and situation penalties', () {
    final results = KeywordSuggester.compute(
      query: 'livraison',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
    );

    expect(results.map((item) => item.label), isNot(contains('Livraison de colis')));
  });

  test('returns popularity fallback compatible with filters', () {
    final results = KeywordSuggester.compute(
      query: 'mot totalement inconnu',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
      limit: 2,
    );

    expect(results, hasLength(2));
    expect(results.first.label, 'Pâtisserie artisanale');
    expect(results.map((item) => item.label), isNot(contains('Livraison de colis')));
  });

  test('empty query returns weighted and popular items with a limit', () {
    final results = KeywordSuggester.compute(
      query: '',
      items: _items,
      limit: 3,
    );

    expect(results, hasLength(3));
    expect(results.first.label, 'Pâtisserie artisanale');
  });

  test('uses shorter labels after equal score and popularity', () {
    const tied = <SuggestionItem>[
      SuggestionItem(label: 'Une étiquette très longue', keywords: <String>[]),
      SuggestionItem(label: 'Court', keywords: <String>[]),
    ];
    final results = KeywordSuggester.compute(query: '', items: tied);
    expect(results.first.label, 'Court');
  });
}
