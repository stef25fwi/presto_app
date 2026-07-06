import '../models/value_analysis.dart';

/// Service for analyzing and calculating marketplace listing values
/// Considers user base, reproduction cost, and resale potential
class ValueAnalysisService {
  // Constants for value calculation
  static const int _standardUserBase = 1000;
  static const double _viewToValueFactor = 0.5;
  static const double _favoriteToValueFactor = 2.0;
  static const double _depreciationPerDay = 0.001;

  // Condition multipliers
  static const Map<String, double> _conditionMultipliers = {
    'new': 1.0,
    'like-new': 0.95,
    'excellent': 0.90,
    'good': 0.80,
    'fair': 0.60,
    'poor': 0.40,
  };

  // Category resale retention rates
  static const Map<String, double> _categoryResaleRetention = {
    'electronics': 0.60,
    'furniture': 0.50,
    'clothing': 0.30,
    'books': 0.25,
    'sports': 0.55,
    'tools': 0.65,
    'jewelry': 0.70,
    'collectibles': 0.75,
    'vehicles': 0.50,
    'general': 0.50,
  };

  /// Calculates comprehensive value analysis for a listing
  static Future<ValueAnalysis> analyzeValue(ValueAnalysisParams params) async {
    final userBaseValue = _calculateUserBaseValue(params);
    final reproductionValue = _calculateReproductionValue(params);
    final resaleValue = _calculateResaleValue(params);

    final totalValue = _calculateTotalValue(
      userBaseValue,
      reproductionValue,
      resaleValue,
      params,
    );

    final breakdown = _calculateBreakdown(
      userBaseValue,
      reproductionValue,
      resaleValue,
      totalValue,
    );

    final factors = _extractValueFactors(params, userBaseValue, resaleValue);
    final confidenceScore = _calculateConfidenceScore(params);

    return ValueAnalysis(
      userBaseValue: userBaseValue,
      reproductionValue: reproductionValue,
      resaleValue: resaleValue,
      totalValue: totalValue,
      breakdown: breakdown,
      confidenceScore: confidenceScore,
      analyzedAt: DateTime.now(),
      factors: factors,
    );
  }

  /// Calculates value based on 1000 active users and market demand
  static double _calculateUserBaseValue(ValueAnalysisParams params) {
    // Base calculation: how much value is derived from having 1000 active users
    final userRatio = params.activeUsers / _standardUserBase;

    // View-based value: more views = higher perceived value
    final viewValue = params.viewCount * _viewToValueFactor * userRatio;

    // Engagement-based value: favorites indicate desirability
    final engagementValue =
        params.favoriteCount * _favoriteToValueFactor * userRatio;

    // Premium boost
    final premiumMultiplier = params.isPremium ? 1.2 : 1.0;

    // Market demand adjustment
    final baseUserValue = (viewValue + engagementValue) * premiumMultiplier;

    return baseUserValue * params.marketDemandMultiplier;
  }

  /// Calculates cost to reproduce or replicate what's being sold
  static double _calculateReproductionValue(ValueAnalysisParams params) {
    // Reproduction value is typically a percentage of the base price
    // Higher for services, lower for used goods
    double reproductionRatio = 0.8; // 80% of base price by default

    // Category-specific reproduction costs
    if (params.category == 'services' || params.category == 'professional') {
      reproductionRatio = 1.2; // Services often cost more to reproduce
    } else if (params.category == 'digital' || params.category == 'software') {
      reproductionRatio = 0.3; // Digital goods have lower reproduction costs
    }

    final ageMultiplier = _calculateAgeDepreciation(params.itemAgeDays);
    final conditionMultiplier =
        _conditionMultipliers[params.itemCondition] ?? 0.8;

    return params.basePrice *
        reproductionRatio *
        conditionMultiplier *
        ageMultiplier;
  }

  /// Calculates potential resale value
  static double _calculateResaleValue(ValueAnalysisParams params) {
    // Resale value depends on item condition and market demand
    final retentionRate = _categoryResaleRetention[params.category] ?? 0.5;

    final conditionMultiplier =
        _conditionMultipliers[params.itemCondition] ?? 0.8;

    // Age affects resale value
    final ageMultiplier = _calculateAgeDepreciation(params.itemAgeDays);

    // Market demand affects resale value
    final demandBoost = params.marketDemandMultiplier * 0.5;

    // Premium listings maintain value better
    final premiumMultiplier = params.isPremium ? 1.15 : 1.0;

    final baseResaleValue =
        params.basePrice * retentionRate * conditionMultiplier * ageMultiplier;

    return baseResaleValue * (1.0 + demandBoost) * premiumMultiplier;
  }

  /// Calculates total value as weighted sum of components
  static double _calculateTotalValue(
    double userBaseValue,
    double reproductionValue,
    double resaleValue,
    ValueAnalysisParams params,
  ) {
    // Define weights for each component
    // Adjust based on item age and market conditions
    final userBaseWeight = 0.30;
    final reproductionWeight = 0.35;
    final resaleWeight = 0.35;

    // Young items favor user base value, older items favor resale value
    double adjustedUserWeight = userBaseWeight;
    double adjustedResaleWeight = resaleWeight;

    if (params.itemAgeDays < 7) {
      adjustedUserWeight = 0.40;
      adjustedResaleWeight = 0.25;
    } else if (params.itemAgeDays > 90) {
      // Les annonces anciennes ne doivent pas gagner artificiellement de la valeur
      // par un surpoids de la revente. La dépréciation est déjà appliquée dans
      // reproductionValue et resaleValue, on réduit donc le poids revente.
      adjustedUserWeight = 0.25;
      adjustedResaleWeight = 0.30;
    }

    final adjustedReproWeight = 1.0 - adjustedUserWeight - adjustedResaleWeight;

    return (userBaseValue * adjustedUserWeight +
            reproductionValue * adjustedReproWeight +
            resaleValue * adjustedResaleWeight)
        .clamp(0, double.infinity);
  }

  /// Calculates breakdown percentages
  static ValueAnalysisBreakdown _calculateBreakdown(
    double userBaseValue,
    double reproductionValue,
    double resaleValue,
    double totalValue,
  ) {
    final total = userBaseValue + reproductionValue + resaleValue;

    final userPercentage = total > 0
        ? (userBaseValue / total * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;
    final reproPercentage = total > 0
        ? (reproductionValue / total * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;
    final resalePercentage = total > 0
        ? (resaleValue / total * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;

    return ValueAnalysisBreakdown(
      userBaseWeight: 0.30,
      reproductionWeight: 0.35,
      resaleWeight: 0.35,
      userBasePercentage: userPercentage,
      reproductionPercentage: reproPercentage,
      resalePercentage: resalePercentage,
    );
  }

  /// Extracts key factors that influenced the value analysis
  static List<ValueFactor> _extractValueFactors(
    ValueAnalysisParams params,
    double userBaseValue,
    double resaleValue,
  ) {
    final factors = <ValueFactor>[];

    // Popularity factor
    if (params.viewCount > 50) {
      factors.add(
        ValueFactor(
          name: 'High Popularity',
          impact: params.viewCount * 0.1,
          description: 'Strong viewer interest indicates good market demand',
          contributionPercentage: 15,
        ),
      );
    }

    // Engagement factor
    if (params.favoriteCount > 10) {
      factors.add(
        ValueFactor(
          name: 'High Engagement',
          impact: params.favoriteCount * 0.2,
          description: 'Multiple favorites show strong buyer interest',
          contributionPercentage: 12,
        ),
      );
    }

    // Condition factor
    final conditionMultiplier =
        _conditionMultipliers[params.itemCondition] ?? 0.8;
    if (conditionMultiplier > 0.8) {
      factors.add(
        ValueFactor(
          name: 'Excellent Condition',
          impact: userBaseValue * 0.1,
          description:
              '${params.itemCondition} condition supports higher valuation',
          contributionPercentage: 10,
        ),
      );
    }

    // Age factor
    if (params.itemAgeDays < 7) {
      factors.add(
        ValueFactor(
          name: 'New Listing',
          impact: userBaseValue * 0.15,
          description: 'Recently posted items often perform better',
          contributionPercentage: 8,
        ),
      );
    }

    // Category factor
    final categoryRetention = _categoryResaleRetention[params.category] ?? 0.5;
    if (categoryRetention > 0.6) {
      factors.add(
        ValueFactor(
          name: 'Strong Category',
          impact: resaleValue * 0.1,
          description: '${params.category} items maintain value well in resale',
          contributionPercentage: 10,
        ),
      );
    }

    // Premium boost factor
    if (params.isPremium) {
      factors.add(
        ValueFactor(
          name: 'Premium Listing',
          impact: userBaseValue * 0.2,
          description: 'Premium features increase visibility and desirability',
          contributionPercentage: 12,
        ),
      );
    }

    return factors;
  }

  /// Calculates age-based depreciation
  static double _calculateAgeDepreciation(int itemAgeDays) {
    final depreciation = 1.0 - (_depreciationPerDay * itemAgeDays);
    return depreciation.clamp(0.3, 1.0);
  }

  /// Calculates confidence score based on available data
  static int _calculateConfidenceScore(ValueAnalysisParams params) {
    int score = 50; // Base score

    // More views = higher confidence
    if (params.viewCount > 100)
      score += 15;
    else if (params.viewCount > 50)
      score += 10;
    else if (params.viewCount > 10) score += 5;

    // More favorites = higher confidence
    if (params.favoriteCount > 20)
      score += 15;
    else if (params.favoriteCount > 10)
      score += 10;
    else if (params.favoriteCount > 5) score += 5;

    // Known category = higher confidence
    if (_categoryResaleRetention.containsKey(params.category)) score += 10;

    // Recent listing = higher confidence
    if (params.itemAgeDays < 14) score += 10;

    // Premium listing = higher confidence in pricing
    if (params.isPremium) score += 5;

    return score.clamp(0, 100);
  }

  /// Formats a value as currency
  static String formatCurrency(double value, {String symbol = '€'}) {
    return '$symbol${value.toStringAsFixed(2)}';
  }

  /// Gets a summary of the value analysis
  static String getSummary(ValueAnalysis analysis) {
    final total = analysis.totalValue;
    final userBase = analysis.breakdown.userBasePercentage;
    final repro = analysis.breakdown.reproductionPercentage;
    final resale = analysis.breakdown.resalePercentage;

    return '''
Valeur Totale Estimée: ${formatCurrency(total)}
- Valeur Utilisateurs (1000): ${formatCurrency(analysis.userBaseValue)} ($userBase%)
- Valeur de Reproduction: ${formatCurrency(analysis.reproductionValue)} ($repro%)
- Valeur de Revente: ${formatCurrency(analysis.resaleValue)} ($resale%)
Score de Confiance: ${analysis.confidenceScore}%
''';
  }
}
