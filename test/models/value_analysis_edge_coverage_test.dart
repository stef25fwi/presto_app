import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/value_analysis.dart';

void main() {
  group('ValueAnalysis edge coverage', () {
    test('copyWith remplace tous les champs sans modifier l original', () {
      final original = ValueAnalysis(
        userBaseValue: 10,
        reproductionValue: 20,
        resaleValue: 30,
        totalValue: 60,
        breakdown: const ValueAnalysisBreakdown(
          userBaseWeight: 10,
          reproductionWeight: 20,
          resaleWeight: 70,
          userBasePercentage: 16.67,
          reproductionPercentage: 33.33,
          resalePercentage: 50,
        ),
        confidenceScore: 70,
        analyzedAt: DateTime.utc(2026, 1, 1),
        factors: const <ValueFactor>[
          ValueFactor(
            name: 'Demande',
            impact: 5,
            description: 'Demande locale',
            contributionPercentage: 10,
          ),
        ],
      );
      const replacementBreakdown = ValueAnalysisBreakdown(
        userBaseWeight: 30,
        reproductionWeight: 30,
        resaleWeight: 40,
        userBasePercentage: 25,
        reproductionPercentage: 25,
        resalePercentage: 50,
      );
      const replacementFactors = <ValueFactor>[
        ValueFactor(
          name: 'Premium',
          impact: 12,
          description: 'Annonce mise en avant',
          contributionPercentage: 20,
        ),
      ];
      final replacementDate = DateTime.utc(2026, 7, 26, 12, 30);

      final copied = original.copyWith(
        userBaseValue: 100,
        reproductionValue: 200,
        resaleValue: 300,
        totalValue: 600,
        breakdown: replacementBreakdown,
        confidenceScore: 95,
        analyzedAt: replacementDate,
        factors: replacementFactors,
      );

      expect(copied.userBaseValue, 100);
      expect(copied.reproductionValue, 200);
      expect(copied.resaleValue, 300);
      expect(copied.totalValue, 600);
      expect(copied.breakdown, same(replacementBreakdown));
      expect(copied.confidenceScore, 95);
      expect(copied.analyzedAt, replacementDate);
      expect(copied.factors, same(replacementFactors));
      expect(original.totalValue, 60);

      final unchanged = original.copyWith();
      expect(unchanged.userBaseValue, original.userBaseValue);
      expect(unchanged.breakdown, same(original.breakdown));
      expect(unchanged.factors, same(original.factors));
    });

    test('fromMap parse la date et les facteurs puis se sérialise', () {
      final parsed = ValueAnalysis.fromMap(<String, dynamic>{
        'userBaseValue': 120,
        'reproductionValue': 80,
        'resaleValue': 100,
        'totalValue': 300,
        'breakdown': <String, dynamic>{
          'userBaseWeight': 40,
          'reproductionWeight': 20,
          'resaleWeight': 40,
          'userBasePercentage': 40,
          'reproductionPercentage': 26.67,
          'resalePercentage': 33.33,
        },
        'confidenceScore': 88,
        'analyzedAt': '2026-07-26T10:15:30.000Z',
        'factors': <Object?>[
          <String, dynamic>{
            'name': 'Historique',
            'impact': -4,
            'description': 'Prix récemment en baisse',
            'contributionPercentage': -2.5,
          },
          'entrée ignorée',
        ],
      });

      expect(parsed.analyzedAt, DateTime.utc(2026, 7, 26, 10, 15, 30));
      expect(parsed.factors, hasLength(1));
      expect(parsed.factors.single.name, 'Historique');
      expect(parsed.factors.single.impact, -4);

      final serialized = parsed.toMap();
      expect(serialized['analyzedAt'], '2026-07-26T10:15:30.000Z');
      expect(
        serialized['factors'],
        <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Historique',
            'impact': -4.0,
            'description': 'Prix récemment en baisse',
            'contributionPercentage': -2.5,
          },
        ],
      );
    });
  });
}
