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

      expect(parsed.analyzedAt.isBefore(before), isFalse);
      expect(parsed.analyzedAt.isAfter(after), isFalse);
      expect(parsed.factors, isEmpty);
    });

    test('convertit les maps compatibles et ignore les autres entrées', () {
      final parsed = ValueAnalysis.fromMap(<String, dynamic>{
        'factors': <Object?>[
          <String, dynamic>{
            'name': 'Saisonnalité',
            'impact': 3,
            'description': 'Demande plus forte en haute saison',
            'contributionPercentage': 1.5,
          },
          <String, Object?>{
            'name': 'Map compatible',
            'impact': 2,
            'description': 'Type générique compatible à l exécution',
            'contributionPercentage': 0.5,
          },
          12,
        ],
      });

      expect(parsed.factors, hasLength(2));
      expect(
        parsed.factors.map((factor) => factor.name),
        <String>['Saisonnalité', 'Map compatible'],
      );
      expect(parsed.factors.first.impact, 3);
      expect(parsed.factors.last.contributionPercentage, 0.5);
    });
  });
}
