import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/keyword_suggester.dart';

void main() {
  group('KeywordSuggester edge coverage', () {
    test('couvre les correspondances par préfixe puis par inclusion', () {
      const items = <SuggestionItem>[
        SuggestionItem(
          label: 'Atelier dessert',
          keywords: <String>['patisserie'],
        ),
      ];

      final prefixResults = KeywordSuggester.compute(
        query: 'patis',
        items: items,
      );
      final containsResults = KeywordSuggester.compute(
        query: 'serie',
        items: items,
      );

      expect(prefixResults.single.label, 'Atelier dessert');
      expect(containsResults.single.label, 'Atelier dessert');
    });

    test('couvre le fuzzy avec arrêt exact à 0,90 et boucle complète', () {
      const items = <SuggestionItem>[
        SuggestionItem(
          label: 'Atelier dessert',
          keywords: <String>['patisserie'],
        ),
        SuggestionItem(
          label: 'Correspondance exacte à 0,90',
          keywords: <String>['abcdefghij'],
        ),
      ];

      final exactBreakResults = KeywordSuggester.compute(
        query: 'abcdxfghij',
        items: items,
      );
      final completedLoopResults = KeywordSuggester.compute(
        query: 'patiseri',
        items: items,
      );

      expect(KeywordSuggester.similarity('abcdxfghij', 'abcdefghij'), 0.9);
      expect(exactBreakResults.first.label, 'Correspondance exacte à 0,90');
      expect(completedLoopResults.first.label, 'Atelier dessert');
    });

    test('déclenche réellement le fallback et filtre le contexte', () {
      const items = <SuggestionItem>[
        SuggestionItem(
          label: 'Compatible prioritaire',
          keywords: <String>[],
          popularity: 10,
        ),
        SuggestionItem(
          label: 'Compatible secondaire',
          keywords: <String>[],
          popularity: 5,
        ),
        SuggestionItem(
          label: 'Mauvaise région',
          keywords: <String>[],
          regions: <String>['Martinique'],
          popularity: 15,
        ),
        SuggestionItem(
          label: 'Mauvaise situation',
          keywords: <String>[],
          situations: <String>['Retraite'],
          popularity: 12,
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
        <String>['Compatible prioritaire', 'Compatible secondaire'],
      );
    });
  });
}
