import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/keyword_suggester.dart';

const _items = <SuggestionItem>[
  SuggestionItem(
    label: 'Patisserie artisanale',
    keywords: <String>['gateau', 'patisserie', 'dessert'],
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
    label: 'Nettoyage a domicile',
    keywords: <String>['menage', 'nettoyage', 'entretien'],
    popularity: 80,
  ),
  SuggestionItem(
    label: 'Creation de site vitrine',
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
  test('normalizes punctuation apostrophes hyphens and whitespace', () {
    expect(
      KeywordSuggester.normalize("  Creation-d'un GATEAU !!!  ").trim(),
      'creation d un gateau',
    );
    expect(KeywordSuggester.normalize('A_B-C'), 'a b c');
    expect(KeywordSuggester.normalize(''), '');
  });

  test('tokenizes while removing stopwords and applying light stemming', () {
    expect(
      KeywordSuggester.tokenize('Je veux creer des livraisons rapides'),
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
      label: 'Menage-Pro',
      keywords: <String>['Nettoyage', 'Proprete'],
      tags: <String>['Service a domicile'],
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
    expect(results.first.label, 'Patisserie artisanale');
    expect(results.length, lessThanOrEqualTo(3));
  });

  test('supports typo fuzzy matching and contains matching', () {
    final typo = KeywordSuggester.compute(
      query: 'patiseri',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
    );
    expect(typo.first.label, 'Patisserie artisanale');

    final contains = KeywordSuggester.compute(
      query: 'domicile',
      items: _items,
    );
    expect(contains.first.label, 'Nettoyage a domicile');
  });

  test('keeps a strong exact match while applying context penalties', () {
    final results = KeywordSuggester.compute(
      query: 'livraison',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
    );

    expect(results, isNotEmpty);
    expect(results.first.label, 'Livraison de colis');
    expect(results.map((item) => item.label), contains('Patisserie artisanale'));
  });

  test('returns a compatible popularity fallback after filters', () {
    final results = KeywordSuggester.compute(
      query: 'mot totalement inconnu',
      items: _items,
      region: 'Guadeloupe',
      situation: 'Sans emploi',
      limit: 2,
    );

    expect(results, hasLength(1));
    expect(results.single.label, 'Patisserie artisanale');
  });

  test('empty query returns the default popularity fallback with a limit', () {
    final results = KeywordSuggester.compute(
      query: '',
      items: _items,
      limit: 3,
    );

    expect(results, hasLength(3));
    expect(
      results.map((item) => item.label).toList(),
      <String>[
        'Nettoyage a domicile',
        'Creation de site vitrine',
        'Cours de coiffure',
      ],
    );
  });

  test('uses shorter labels after equal score and popularity', () {
    const tied = <SuggestionItem>[
      SuggestionItem(label: 'Une etiquette tres longue', keywords: <String>[]),
      SuggestionItem(label: 'Court', keywords: <String>[]),
    ];
    final results = KeywordSuggester.compute(query: '', items: tied);
    expect(results.first.label, 'Court');
  });
}
