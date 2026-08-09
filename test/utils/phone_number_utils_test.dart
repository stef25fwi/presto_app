import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/phone_number_utils.dart';

void main() {
  group('phone number utils', () {
    test('normalise un mobile métropole avec zéro national', () {
      expect(
        normalizePhoneNumberE164(countryCode: '+33', rawPhone: '06 12 34 56 78'),
        '+33612345678',
      );
    });

    test('normalise un mobile Guadeloupe avec zéro national', () {
      expect(
        normalizePhoneNumberE164(countryCode: '+590', rawPhone: '0690 12 34 56'),
        '+590690123456',
      );
    });

    test('conserve un numéro international explicite', () {
      expect(
        normalizePhoneNumberE164(countryCode: '+33', rawPhone: '+590690123456'),
        '+590690123456',
      );
    });

    test('déduit les indicatifs depuis les départements', () {
      expect(phoneCountryCodeForDepartment('971'), '+590');
      expect(phoneCountryCodeForDepartment('972'), '+596');
      expect(phoneCountryCodeForDepartment('973'), '+594');
      expect(phoneCountryCodeForDepartment('974'), '+262');
      expect(phoneCountryCodeForDepartment('976'), '+262');
      expect(phoneCountryCodeForDepartment('987'), '+689');
      expect(phoneCountryCodeForDepartment('75'), '+33');
    });

    test('sépare indicatif et numéro local E.164', () {
      expect(phoneCountryCodeFromE164('+590690123456'), '+590');
      expect(phoneLocalNumberFromE164('+590690123456'), '690123456');
    });

    test('valide uniquement le format E.164 attendu', () {
      expect(isValidE164PhoneNumber('+33612345678'), isTrue);
      expect(isValidE164PhoneNumber('+590690123456'), isTrue);
      expect(isValidE164PhoneNumber('0612345678'), isFalse);
    });
  });
}
