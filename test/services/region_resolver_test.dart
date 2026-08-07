import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/region_resolver.dart';

void main() {
  group('inferRegionFromPostalCode', () {
    test('resolves overseas departments and Corse', () {
      expect(inferRegionFromPostalCode('97100'), 'Guadeloupe');
      expect(inferRegionFromPostalCode('97200'), 'Martinique');
      expect(inferRegionFromPostalCode('97300'), 'Guyane');
      expect(inferRegionFromPostalCode('97400'), 'La Réunion');
      expect(inferRegionFromPostalCode('97600'), 'Mayotte');
      expect(inferRegionFromPostalCode('20000'), 'Corse');
    });

    test('resolves every metropolitan region family', () {
      expect(inferRegionFromPostalCode('69001'), 'Auvergne-Rhône-Alpes');
      expect(inferRegionFromPostalCode('21000'), 'Bourgogne-Franche-Comté');
      expect(inferRegionFromPostalCode('35000'), 'Bretagne');
      expect(inferRegionFromPostalCode('45000'), 'Centre-Val de Loire');
      expect(inferRegionFromPostalCode('67000'), 'Grand Est');
      expect(inferRegionFromPostalCode('59000'), 'Hauts-de-France');
      expect(inferRegionFromPostalCode('75001'), 'Île-de-France');
      expect(inferRegionFromPostalCode('76000'), 'Normandie');
      expect(inferRegionFromPostalCode('33000'), 'Nouvelle-Aquitaine');
      expect(inferRegionFromPostalCode('31000'), 'Occitanie');
      expect(inferRegionFromPostalCode('44000'), 'Pays de la Loire');
      expect(
        inferRegionFromPostalCode('13000'),
        "Provence-Alpes-Côte d'Azur",
      );
    });

    test('trims input and rejects unsupported or malformed values', () {
      expect(inferRegionFromPostalCode(' 97100 '), 'Guadeloupe');
      expect(inferRegionFromPostalCode(''), isNull);
      expect(inferRegionFromPostalCode('9'), isNull);
      expect(inferRegionFromPostalCode('XX000'), isNull);
      expect(inferRegionFromPostalCode('98000'), isNull);
    });
  });
}
