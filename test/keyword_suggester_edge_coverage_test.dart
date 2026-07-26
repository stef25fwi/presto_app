import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/keyword_suggester.dart';

void main() {
  group('KeywordSuggester edge coverage', () {
    test('couvre la correspondance par préfixe dans le pool', () {
      const items = <SuggestionItem>[
        SuggestionItem(
          label: 'Patisserie artisanale',
          keywords: <String>['patisserie'],
        ),
      ];

      final results = KeywordSuggester.compute(
        query: 'patis',
        items: items,
      );

      expect(results, hasLength(1));
      expect(results.single.label, 'Patisserie artisanale');
    });

    test('arrête le fuzzy dès que la similarité atteint 0,90', () {
      const items = <SuggestionItem>[
        SuggestionItem(
          label: 'Atelier dessert',
          keywords: <String>['patisserie'],
        ),
      ];

      final results = KeywordSuggester.compute(
        query: 'patisseri',
        items: items,
      );

      expect(results, hasLength(1));
      expect(results.single.label, 'Atelier dessert');
    });

    test('retombe sur les plus populaires compatibles après filtrage', () {
      const items = <SuggestionItem>[
        SuggestionItem(
          label: 'Compatible prioritaire',
          keywords: <String>[],
          regions: <String>['Guadeloupe'],
          situations: <String>['Sans emploi'],
          popularity: 90,
        ),
        SuggestionItem(
          label: 'Compatible global',
          keywords: <String>[],
          popularity: 80,
        ),
        SuggestionItem(
          label: 'Mauvaise région',
          keywords: <String>[],
          regions: <String>['Martinique'],
          popularity: 95,
        ),
        SuggestionItem(
          label: 'Mauvaise situation',
          keywords: <String>[],
          regions: <String>['Guadeloupe'],
          situations: <String>['Retraite'],
          popularity: 92,
        ),
      ];

      final results = KeywordSuggester.compute(
        query: 'motintrouvable',
        items: items,
        region: 'Guadeloupe',
        situation: 'Sans emploi',
        limit: 2,
      );

      expect(
        results.map((item) => item.label).toList(),
        <String>['Compatible prioritaire', 'Compatible global'],
      );
    });
  });
}
