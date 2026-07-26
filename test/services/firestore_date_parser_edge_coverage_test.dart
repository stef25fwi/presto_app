import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/firestore_date_parser.dart';

void main() {
  group('parseFirestoreDateTime double coverage', () {
    test('normalise les secondes décimales en millisecondes', () {
      final parsed = parseFirestoreDateTime(1700000000.9);

      expect(parsed, isNotNull);
      expect(parsed!.millisecondsSinceEpoch, 1700000000000);
    });

    test('conserve les millisecondes après troncature', () {
      final parsed = parseFirestoreDateTime(1700000000123.9);

      expect(parsed, isNotNull);
      expect(parsed!.millisecondsSinceEpoch, 1700000000123);
    });

    test('rejette les doubles invalides ou non positifs', () {
      expect(parseFirestoreDateTime(double.nan), isNull);
      expect(parseFirestoreDateTime(double.infinity), isNull);
      expect(parseFirestoreDateTime(double.negativeInfinity), isNull);
      expect(parseFirestoreDateTime(0.0), isNull);
      expect(parseFirestoreDateTime(-1.5), isNull);
    });
  });
}
