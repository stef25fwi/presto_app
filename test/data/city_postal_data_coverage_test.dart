import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/data/city_postal_data.dart';

void main() {
  group('CityPostalData coverage', () {
    test('retrouve une ville par code postal et retourne null sinon', () {
      final city = findCityByPostalCode('97122');

      expect(city, isNotNull);
      expect(city!.city, 'Baie-Mahault');
      expect(city.region, 'Guadeloupe');
      expect(findCityByPostalCode('00000'), isNull);
    });

    test('rejette un préfixe vide', () {
      expect(searchCitiesByPrefix('   '), isEmpty);
    });

    test('recherche par nom de ville sans tenir compte de la casse', () {
      final results = searchCitiesByPrefix('  baie  ');

      expect(results, isNotEmpty);
      expect(results.first.city, 'Baie-Mahault');
    });

    test('recherche par préfixe de code postal', () {
      final results = searchCitiesByPrefix('973');

      expect(results, isNotEmpty);
      expect(results.every((city) => city.postalCode.startsWith('973')), isTrue);
      expect(results.map((city) => city.region).toSet(), {'Guyane'});
    });
  });
}
