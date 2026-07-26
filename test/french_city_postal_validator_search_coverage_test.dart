import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/city_search.dart';
import 'package:presto_app/services/french_city_postal_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await CitySearch.instance.ensureLoaded();
  });

  group('FrenchCityPostalValidator search coverage', () {
    test('recherche une commune uniquement par code postal', () {
      final results = FrenchCityPostalValidator.instance.searchSuggestions(
        '',
        postalCodeHint: '97121',
        limit: 50,
      );

      expect(results, isNotEmpty);
      expect(results.every((city) => city.postalCode == '97121'), isTrue);
      expect(results.any((city) => city.name == 'Anse-Bertrand'), isTrue);
    });

    test('utilise la recherche fuzzy pour une ville très proche', () {
      final results = FrenchCityPostalValidator.instance.searchSuggestions(
        'hans bertrand',
        postalCodeHint: '97121',
        limit: 20,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, 'Anse-Bertrand');
      expect(results.first.postalCode, '97121');
    });

    test('trie les candidats et respecte la limite demandée', () {
      final allResults = FrenchCityPostalValidator.instance.searchSuggestions(
        'saint',
        limit: 50,
      );
      final limitedResults = FrenchCityPostalValidator.instance.searchSuggestions(
        'saint',
        limit: 1,
      );

      expect(allResults.length, greaterThan(1));
      expect(limitedResults, hasLength(1));
      expect(limitedResults.single.name, allResults.first.name);
      expect(limitedResults.single.postalCode, allResults.first.postalCode);
    });

    test('rejette un code postal incompatible avec une ville exacte', () {
      final result = FrenchCityPostalValidator.instance.resolveExactTypedCity(
        city: 'Sainte-Anne',
        postalCode: '97110',
      );

      expect(result, isNull);
    });

    test('classe en priorité une correspondance ville et code postal', () {
      final results = FrenchCityPostalValidator.instance.searchSuggestions(
        'anse',
        postalCodeHint: '97121',
        limit: 10,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, 'Anse-Bertrand');
      expect(results.first.postalCode, '97121');
    });
  });
}
