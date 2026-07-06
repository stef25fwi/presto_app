import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/value_analysis.dart';
import 'package:presto_app/services/value_analysis_service.dart';

void main() {
  group('ValueAnalysisService', () {
    test('calculates value with 1000 users + reproduction + resale', () async {
      // Example: An electronics item with standard metrics
      final params = ValueAnalysisParams(
        basePrice: 500.0,
        activeUsers: 1000,
        viewCount: 75,
        favoriteCount: 12,
        itemAgeDays: 5,
        marketDemandMultiplier: 1.0,
        itemCondition: 'like-new',
        category: 'electronics',
        isPremium: true,
      );

      final analysis = await ValueAnalysisService.analyzeValue(params);

      // Verify all three value components are calculated
      expect(analysis.userBaseValue, greaterThan(0));
      expect(analysis.reproductionValue, greaterThan(0));
      expect(analysis.resaleValue, greaterThan(0));
      expect(analysis.totalValue, greaterThan(0));

      // Verify breakdown percentages sum to 100
      final totalPercentage = analysis.breakdown.userBasePercentage +
          analysis.breakdown.reproductionPercentage +
          analysis.breakdown.resalePercentage;
      expect(totalPercentage, closeTo(100.0, 0.1));

      // Verify confidence score is valid
      expect(analysis.confidenceScore, greaterThanOrEqualTo(0));
      expect(analysis.confidenceScore, lessThanOrEqualTo(100));

      print('Value Analysis Summary:');
      print(ValueAnalysisService.getSummary(analysis));
    });

    test('user base value increases with views and engagement', () async {
      final params1 = ValueAnalysisParams(
        basePrice: 100.0,
        activeUsers: 1000,
        viewCount: 10,
        favoriteCount: 1,
        itemAgeDays: 1,
        category: 'general',
      );

      final params2 = ValueAnalysisParams(
        basePrice: 100.0,
        activeUsers: 1000,
        viewCount: 100,
        favoriteCount: 20,
        itemAgeDays: 1,
        category: 'general',
      );

      final analysis1 = await ValueAnalysisService.analyzeValue(params1);
      final analysis2 = await ValueAnalysisService.analyzeValue(params2);

      expect(analysis2.userBaseValue, greaterThan(analysis1.userBaseValue));
    });

    test('reproduction value considers item condition', () async {
      final paramsNew = ValueAnalysisParams(
        basePrice: 200.0,
        activeUsers: 1000,
        viewCount: 20,
        favoriteCount: 2,
        itemAgeDays: 1,
        itemCondition: 'new',
        category: 'electronics',
      );

      final paramsPoor = ValueAnalysisParams(
        basePrice: 200.0,
        activeUsers: 1000,
        viewCount: 20,
        favoriteCount: 2,
        itemAgeDays: 1,
        itemCondition: 'poor',
        category: 'electronics',
      );

      final analysisNew = await ValueAnalysisService.analyzeValue(paramsNew);
      final analysisPoor = await ValueAnalysisService.analyzeValue(paramsPoor);

      expect(analysisNew.reproductionValue,
          greaterThan(analysisPoor.reproductionValue));
    });

    test('resale value depends on category retention rate', () async {
      final paramsJewelry = ValueAnalysisParams(
        basePrice: 300.0,
        activeUsers: 1000,
        viewCount: 30,
        favoriteCount: 3,
        itemAgeDays: 5,
        category: 'jewelry',
      );

      final paramsClothing = ValueAnalysisParams(
        basePrice: 300.0,
        activeUsers: 1000,
        viewCount: 30,
        favoriteCount: 3,
        itemAgeDays: 5,
        category: 'clothing',
      );

      final analysisJewelry =
          await ValueAnalysisService.analyzeValue(paramsJewelry);
      final analysisClothing =
          await ValueAnalysisService.analyzeValue(paramsClothing);

      // Jewelry has higher retention (0.70 vs 0.30)
      expect(analysisJewelry.resaleValue,
          greaterThan(analysisClothing.resaleValue));
    });

    test('premium listings have higher value multiplier', () async {
      final paramsStandard = ValueAnalysisParams(
        basePrice: 250.0,
        activeUsers: 1000,
        viewCount: 40,
        favoriteCount: 5,
        itemAgeDays: 3,
        isPremium: false,
        category: 'general',
      );

      final paramsPremium = ValueAnalysisParams(
        basePrice: 250.0,
        activeUsers: 1000,
        viewCount: 40,
        favoriteCount: 5,
        itemAgeDays: 3,
        isPremium: true,
        category: 'general',
      );

      final analysisStandard =
          await ValueAnalysisService.analyzeValue(paramsStandard);
      final analysisPremium =
          await ValueAnalysisService.analyzeValue(paramsPremium);

      expect(
          analysisPremium.totalValue, greaterThan(analysisStandard.totalValue));
    });

    test('value decreases with item age (depreciation)', () async {
      final paramsNew = ValueAnalysisParams(
        basePrice: 400.0,
        activeUsers: 1000,
        viewCount: 50,
        favoriteCount: 8,
        itemAgeDays: 1,
        category: 'electronics',
      );

      final paramsOld = ValueAnalysisParams(
        basePrice: 400.0,
        activeUsers: 1000,
        viewCount: 50,
        favoriteCount: 8,
        itemAgeDays: 180,
        category: 'electronics',
      );

      final analysisNew = await ValueAnalysisService.analyzeValue(paramsNew);
      final analysisOld = await ValueAnalysisService.analyzeValue(paramsOld);

      expect(analysisNew.totalValue, greaterThan(analysisOld.totalValue));
    });

    test('factors are extracted from analysis', () async {
      final params = ValueAnalysisParams(
        basePrice: 500.0,
        activeUsers: 1000,
        viewCount: 75,
        favoriteCount: 15,
        itemAgeDays: 2,
        itemCondition: 'like-new',
        category: 'jewelry',
        isPremium: true,
      );

      final analysis = await ValueAnalysisService.analyzeValue(params);

      expect(analysis.factors, isNotEmpty);
      expect(analysis.factors.length, greaterThan(0));

      // Verify each factor has required properties
      for (final factor in analysis.factors) {
        expect(factor.name, isNotEmpty);
        expect(factor.impact, isNotNull);
        expect(factor.description, isNotEmpty);
        expect(factor.contributionPercentage, greaterThanOrEqualTo(0));
      }

      print('Extracted Factors:');
      for (final factor in analysis.factors) {
        print('  - ${factor.name}: ${factor.description}');
      }
    });

    test('confidence score reflects data completeness', () async {
      final paramsLimited = ValueAnalysisParams(
        basePrice: 100.0,
        activeUsers: 100,
        viewCount: 1,
        favoriteCount: 0,
        itemAgeDays: 60,
        category: 'unknown',
      );

      final paramsComplete = ValueAnalysisParams(
        basePrice: 100.0,
        activeUsers: 1000,
        viewCount: 150,
        favoriteCount: 30,
        itemAgeDays: 5,
        category: 'electronics',
        isPremium: true,
      );

      final analysisLimited =
          await ValueAnalysisService.analyzeValue(paramsLimited);
      final analysisComplete =
          await ValueAnalysisService.analyzeValue(paramsComplete);

      expect(analysisComplete.confidenceScore,
          greaterThan(analysisLimited.confidenceScore));
    });

    test('currency formatting works correctly', () {
      expect(ValueAnalysisService.formatCurrency(100.50), '€100.50');
      expect(ValueAnalysisService.formatCurrency(1234.99, symbol: '\$'),
          '\$1234.99');
    });

    test('serialization and deserialization works', () async {
      final params = ValueAnalysisParams(
        basePrice: 350.0,
        activeUsers: 1000,
        viewCount: 60,
        favoriteCount: 10,
        itemAgeDays: 7,
        category: 'furniture',
      );

      final analysis = await ValueAnalysisService.analyzeValue(params);
      final map = analysis.toMap();
      final reconstructed = ValueAnalysis.fromMap(map);

      expect(reconstructed.userBaseValue, analysis.userBaseValue);
      expect(reconstructed.reproductionValue, analysis.reproductionValue);
      expect(reconstructed.resaleValue, analysis.resaleValue);
      expect(reconstructed.totalValue, analysis.totalValue);
      expect(reconstructed.confidenceScore, analysis.confidenceScore);
    });
  });
}
