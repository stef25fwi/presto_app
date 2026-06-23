import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/firestore_date_parser.dart';

void main() {
  test('parseFirestoreDateTime supporte Timestamp et DateTime', () {
    final date = DateTime(2026, 3, 27, 14, 30);

    expect(parseFirestoreDateTime(Timestamp.fromDate(date)), date);
    expect(parseFirestoreDateTime(date), date);
  });

  test('parseFirestoreDateTime supporte epoch secondes et millisecondes', () {
    final date = DateTime.fromMillisecondsSinceEpoch(1711549800000);

    expect(parseFirestoreDateTime(1711549800), date);
    expect(parseFirestoreDateTime(1711549800000), date);
    expect(parseFirestoreDateTime('1711549800'), date);
  });

  test('parseFirestoreDateTime supporte chaine ISO et map Firestore serialisee',
      () {
    final date = DateTime(2026, 3, 27, 14, 30);

    expect(parseFirestoreDateTime(date.toIso8601String()), date);
    expect(
      parseFirestoreDateTime({
        '_seconds': date.millisecondsSinceEpoch ~/ 1000,
        '_nanoseconds': 0,
      }),
      date,
    );
  });

  test('parseFirestoreDateTime retourne null pour valeurs invalides', () {
    expect(parseFirestoreDateTime(null), isNull);
    expect(parseFirestoreDateTime(''), isNull);
    expect(parseFirestoreDateTime(0), isNull);
  });
}
