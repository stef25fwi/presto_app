import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/multi_city_repo.dart';

void main() {
  group('CityRecord', () {
    test('fromJson lit les clés canoniques', () {
      final city = CityRecord.fromJson(<String, dynamic>{
        'name': 'Les Abymes',
        'cp': '97139',
        'dept': '971',
        'region': 'Guadeloupe',
      });

      expect(city.name, 'Les Abymes');
      expect(city.cp, '97139');
      expect(city.dept, '971');
      expect(city.region, 'Guadeloupe');
    });

    test('fromJson accepte les alias et les valeurs numériques', () {
      final postalAlias = CityRecord.fromJson(<String, dynamic>{
        'ville': 'Paris',
        'postalCode': 75001,
        'department': 75,
      });
      final postcodeAlias = CityRecord.fromJson(<String, dynamic>{
        'city': 'Cayenne',
        'postcode': '97300',
        'dept': '973',
      });

      expect(postalAlias.name, 'Paris');
      expect(postalAlias.cp, '75001');
      expect(postalAlias.dept, '75');
      expect(postalAlias.region, isNull);
      expect(postcodeAlias.name, 'Cayenne');
      expect(postcodeAlias.cp, '97300');
      expect(postcodeAlias.dept, '973');
    });

    test('fromJson fournit des chaînes vides lorsque les clés manquent', () {
      final city = CityRecord.fromJson(<String, dynamic>{});

      expect(city.name, isEmpty);
      expect(city.cp, isEmpty);
      expect(city.dept, isEmpty);
      expect(city.region, isNull);
    });
  });

  group('MultiCityRepo.deptFromPostalCode', () {
    final repo = MultiCityRepo();

    test('retourne null pour une valeur absente ou sans code à cinq chiffres', () {
      expect(repo.deptFromPostalCode(null), isNull);
      expect(repo.deptFromPostalCode(''), isNull);
      expect(repo.deptFromPostalCode('9712'), isNull);
      expect(repo.deptFromPostalCode('code inconnu'), isNull);
    });

    test('déduit les départements métropolitains', () {
      expect(repo.deptFromPostalCode('75001'), '75');
      expect(repo.deptFromPostalCode('Adresse : 13008 Marseille'), '13');
      expect(repo.deptFromPostalCode('20100 Sartène'), '20');
    });

    test('conserve trois chiffres pour les codes 97 et 98', () {
      expect(repo.deptFromPostalCode('97139'), '971');
      expect(repo.deptFromPostalCode('97200 Fort-de-France'), '972');
      expect(repo.deptFromPostalCode('98714'), '987');
    });

    test('utilise le premier code postal complet trouvé', () {
      expect(repo.deptFromPostalCode('97139 puis 75001'), '971');
    });
  });

  test('search retourne immédiatement une liste vide pour une requête vide',
      () async {
    final repo = MultiCityRepo();

    expect(await repo.search(''), isEmpty);
    expect(await repo.search('   '), isEmpty);
  });
}
