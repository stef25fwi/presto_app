import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/profile_department_resolver.dart';

void main() {
  group('ProfileDepartmentResolver', () {
    test('normalise les codes métropole, Corse et DOM', () {
      expect(ProfileDepartmentResolver.normalizeDepartmentCode(null), isNull);
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('  '), isNull);
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('2a'), '2A');
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('2B'), '2B');
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('1'), '01');
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('75 Paris'), '75');
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('97120'), '971');
      expect(ProfileDepartmentResolver.normalizeDepartmentCode('abc'), isNull);
    });

    test('déduit le département depuis un code postal', () {
      expect(ProfileDepartmentResolver.departmentCodeFromPostalCode(null), isNull);
      expect(ProfileDepartmentResolver.departmentCodeFromPostalCode('x'), isNull);
      expect(ProfileDepartmentResolver.departmentCodeFromPostalCode('97122'), '971');
      expect(ProfileDepartmentResolver.departmentCodeFromPostalCode('75001'), '75');
      expect(ProfileDepartmentResolver.departmentCodeFromPostalCode('20000'), '2A');
      expect(ProfileDepartmentResolver.departmentCodeFromPostalCode(' 33 000 '), '33');
    });

    test('déduit le code depuis un libellé accentué ou un code brut', () {
      expect(ProfileDepartmentResolver.departmentCodeFromLabel('Guadeloupe'), '971');
      expect(ProfileDepartmentResolver.departmentCodeFromLabel('Côtes-d’Armor'), '22');
      expect(ProfileDepartmentResolver.departmentCodeFromLabel('  paris '), '75');
      expect(ProfileDepartmentResolver.departmentCodeFromLabel('972'), '972');
      expect(ProfileDepartmentResolver.departmentCodeFromLabel(''), isNull);
    });

    test('déduit le code depuis les villes et codes postaux embarqués', () {
      expect(ProfileDepartmentResolver.departmentCodeFromCity('Baie-Mahault'), '971');
      expect(ProfileDepartmentResolver.departmentCodeFromCity('Pointe-à-Pitre'), '971');
      expect(ProfileDepartmentResolver.departmentCodeFromCity('Adresse 97118 Saint-François'), '971');
      expect(ProfileDepartmentResolver.departmentCodeFromCity('Paris 75001'), '75');
      expect(ProfileDepartmentResolver.departmentCodeFromCity('Ville inconnue'), isNull);
      expect(ProfileDepartmentResolver.departmentCodeFromCity(''), isNull);
    });

    test('respecte l ordre de priorité des sources', () {
      expect(
        ProfileDepartmentResolver.resolveDepartmentCode(
          city: 'Baie-Mahault',
          postalCode: '97200',
          departmentLabel: 'Guyane',
          departmentCode: '974',
        ),
        '974',
      );
      expect(
        ProfileDepartmentResolver.resolveDepartmentCode(
          city: 'Baie-Mahault',
          postalCode: '97200',
          departmentLabel: 'Guyane',
        ),
        '973',
      );
      expect(
        ProfileDepartmentResolver.resolveDepartmentCode(
          city: 'Baie-Mahault',
          postalCode: '97200',
        ),
        '972',
      );
      expect(
        ProfileDepartmentResolver.resolveDepartmentCode(city: 'Baie-Mahault'),
        '971',
      );
    });

    test('formate les noms connus et conserve les codes inconnus', () {
      expect(ProfileDepartmentResolver.departmentDisplayName('971'), '971 - Guadeloupe');
      expect(ProfileDepartmentResolver.departmentDisplayName('1'), '01 - Ain');
      expect(ProfileDepartmentResolver.departmentDisplayName('999'), '999');
    });
  });
}
