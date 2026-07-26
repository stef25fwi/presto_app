import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/value_analysis.dart';

void main() {
  group('ValueAnalysis remaining coverage', () {
    test('utilise une date de repli pour une valeur non textuelle', () {
      final before = DateTime.now();
      final parsed = ValueAnalysis.fromMap(<String, dynamic>{
        'analyzedAt': 42,
      });
      final after = DateTime.now();

      expect(
        parsed.analyzedAt.isBefore(before),
        isFalse,
      );
      expect(
        parsed.analyzedAt.isAfter(after),
        isFalse,
      );
      expect(parsed.factors, isEmpty);
    });

    test('convertit une liste de facteurs typés et ignore les autres entrées', () {
      final parsed = ValueAnalysis.fromMap(<String, dynamic>{
        'factors': <Object?>[
          <String, dynamic>{
            'name': 'Saisonnalité',
            'impact': 3,
            'description': 'Demande plus forte en haute saison',
            'contributionPercentage': 1.5,
          },
          <String, Object?>{'name': 'map non dynamique'},
          12,
        ],
      });

      expect(parsed.factors, hasLength(1));
      expect(parsed.factors.single.name, 'Saisonnalité');
      expect(parsed.factors.single.impact, 3);
      expect(parsed.factors.single.contributionPercentage, 1.5);
    });
  });
}
