import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/french_city_postal_validator.dart';

void main() {
  test('validate Sainte-Anne 97180', () {
    final result = FrenchCityPostalValidator.instance.validate(
      city: 'Sainte-Anne',
      postalCode: '97180',
    );

    expect(result.isValid, isTrue);
    expect(result.canonicalCity?.name, 'Sainte-Anne');
    expect(result.canonicalCity?.postalCode, '97180');
  });

  test('validate Sainte Anne 97180', () {
    final result = FrenchCityPostalValidator.instance.validate(
      city: 'Sainte Anne',
      postalCode: '97180',
    );

    expect(result.isValid, isTrue);
  });

  test('validate SAINTE ANNE 97180', () {
    final result = FrenchCityPostalValidator.instance.validate(
      city: 'SAINTE ANNE',
      postalCode: '97180',
    );

    expect(result.isValid, isTrue);
  });

  test('validate STE ANNE 97180', () {
    final result = FrenchCityPostalValidator.instance.validate(
      city: 'STE ANNE',
      postalCode: '97180',
    );

    expect(result.isValid, isTrue);
  });

  test('validate Sainte-Anne 97110 rejects mismatched postal code', () {
    final result = FrenchCityPostalValidator.instance.validate(
      city: 'Sainte-Anne',
      postalCode: '97110',
    );

    expect(result.isValid, isFalse);
    expect(result.isKnownCity, isTrue);
    expect(result.postalCodeMatches, isFalse);
  });
}
