import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/publish_ai/profile_readiness.dart';

void main() {
  group('ProfileReadinessChecker.resolveLocation', () {
    test('accepts city and postalCode aliases', () {
      final location = ProfileReadinessChecker.resolveLocation({
        'commune': 'Melun',
        'cp': '77000',
      });

      expect(location.city, 'Melun');
      expect(location.citySource, 'commune');
      expect(location.postalCode, '77000');
      expect(location.postalCodeSource, 'cp');
      expect(location.blockReason, 'none');
    });

    test('accepts legacy snake_case postal aliases', () {
      final location = ProfileReadinessChecker.resolveLocation({
        'locality': 'Paris',
        'postal_code': '75001',
      });

      expect(location.city, 'Paris');
      expect(location.citySource, 'locality');
      expect(location.postalCode, '75001');
      expect(location.postalCodeSource, 'postal_code');
      expect(location.blockReason, 'none');
    });

    test('reports exact missing location reason', () {
      final location = ProfileReadinessChecker.resolveLocation({
        'displayName': 'Admin',
      });

      expect(location.city, isEmpty);
      expect(location.postalCode, isEmpty);
      expect(location.blockReason, 'missing city and postalCode');
    });
  });
}
