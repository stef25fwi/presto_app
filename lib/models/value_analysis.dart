/// Represents a comprehensive value analysis of a marketplace listing
class ValueAnalysis {
  /// Value based on user demand with 1000 active users
  final double userBaseValue;

  /// Cost to reproduce or replicate the item/service
  final double reproductionValue;

  /// Potential resale value of the item
  final double resaleValue;

  /// Total calculated value (weighted sum of all components)
  final double totalValue;

  /// Breakdown of how the total value was calculated
  final ValueAnalysisBreakdown breakdown;

  /// Confidence score (0-100) indicating reliability of the analysis
  final int confidenceScore;

  /// Timestamp when the analysis was performed
  final DateTime analyzedAt;

  /// Additional factors considered in the analysis
  final List<ValueFactor> factors;

  const ValueAnalysis({
    required this.userBaseValue,
    required this.reproductionValue,
    required this.resaleValue,
    required this.totalValue,
    required this.breakdown,
    required this.confidenceScore,
    required this.analyzedAt,
    required this.factors,
  });

  /// Create a copy with modified fields
  ValueAnalysis copyWith({
    double? userBaseValue,
    double? reproductionValue,
    double? resaleValue,
    double? totalValue,
    ValueAnalysisBreakdown? breakdown,
    int? confidenceScore,
    DateTime? analyzedAt,
    List<ValueFactor>? factors,
  }) {
    return ValueAnalysis(
      userBaseValue: userBaseValue ?? this.userBaseValue,
      reproductionValue: reproductionValue ?? this.reproductionValue,
      resaleValue: resaleValue ?? this.resaleValue,
      totalValue: totalValue ?? this.totalValue,
      breakdown: breakdown ?? this.breakdown,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      factors: factors ?? this.factors,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userBaseValue': userBaseValue,
      'reproductionValue': reproductionValue,
      'resaleValue': resaleValue,
      'totalValue': totalValue,
      'breakdown': breakdown.toMap(),
      'confidenceScore': confidenceScore,
      'analyzedAt': analyzedAt.toIso8601String(),
      'factors': factors.map((f) => f.toMap()).toList(),
    };
  }

  /// Create from map
  factory ValueAnalysis.fromMap(Map<String, dynamic> map) {
    return ValueAnalysis(
      userBaseValue:
          (map['userBaseValue'] as num?)?.toDouble() ?? 0.0,
      reproductionValue:
          (map['reproductionValue'] as num?)?.toDouble() ?? 0.0,
      resaleValue: (map['resaleValue'] as num?)?.toDouble() ?? 0.0,
      totalValue: (map['totalValue'] as num?)?.toDouble() ?? 0.0,
      breakdown: ValueAnalysisBreakdown.fromMap(
        map['breakdown'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      confidenceScore: (map['confidenceScore'] as num?)?.toInt() ?? 0,
      analyzedAt: map['analyzedAt'] is String
          ? DateTime.parse(map['analyzedAt'] as String)
          : DateTime.now(),
      factors: (map['factors'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((f) => ValueFactor.fromMap(f))
              .toList() ??
          [],
    );
  }
}

/// Breakdown of value calculation with weights and percentages
class ValueAnalysisBreakdown {
  /// Weight given to user base value (0-100)
  final double userBaseWeight;

  /// Weight given to reproduction value (0-100)
  final double reproductionWeight;

  /// Weight given to resale value (0-100)
  final double resaleWeight;

  /// Percentage of total value from user base
  final double userBasePercentage;

  /// Percentage of total value from reproduction
  final double reproductionPercentage;

  /// Percentage of total value from resale
  final double resalePercentage;

  const ValueAnalysisBreakdown({
    required this.userBaseWeight,
    required this.reproductionWeight,
    required this.resaleWeight,
    required this.userBasePercentage,
    required this.reproductionPercentage,
    required this.resalePercentage,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userBaseWeight': userBaseWeight,
      'reproductionWeight': reproductionWeight,
      'resaleWeight': resaleWeight,
      'userBasePercentage': userBasePercentage,
      'reproductionPercentage': reproductionPercentage,
      'resalePercentage': resalePercentage,
    };
  }

  factory ValueAnalysisBreakdown.fromMap(Map<String, dynamic> map) {
    return ValueAnalysisBreakdown(
      userBaseWeight: (map['userBaseWeight'] as num?)?.toDouble() ?? 0.0,
      reproductionWeight:
          (map['reproductionWeight'] as num?)?.toDouble() ?? 0.0,
      resaleWeight: (map['resaleWeight'] as num?)?.toDouble() ?? 0.0,
      userBasePercentage:
          (map['userBasePercentage'] as num?)?.toDouble() ?? 0.0,
      reproductionPercentage:
          (map['reproductionPercentage'] as num?)?.toDouble() ?? 0.0,
      resalePercentage:
          (map['resalePercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents a factor that contributed to the value analysis
class ValueFactor {
  /// Name of the factor
  final String name;

  /// Impact on the total value (positive or negative)
  final double impact;

  /// Description of why this factor matters
  final String description;

  /// Contribution percentage to the total value
  final double contributionPercentage;

  const ValueFactor({
    required this.name,
    required this.impact,
    required this.description,
    required this.contributionPercentage,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'impact': impact,
      'description': description,
      'contributionPercentage': contributionPercentage,
    };
  }

  factory ValueFactor.fromMap(Map<String, dynamic> map) {
    return ValueFactor(
      name: map['name'] as String? ?? '',
      impact: (map['impact'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      contributionPercentage:
          (map['contributionPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Parameters for value analysis calculation
class ValueAnalysisParams {
  /// Base price of the listing
  final double basePrice;

  /// Number of active users in the marketplace
  final int activeUsers;

  /// Number of views/interactions the listing has received
  final int viewCount;

  /// Number of favorites/wishlist additions
  final int favoriteCount;

  /// Item age in days
  final int itemAgeDays;

  /// Market demand multiplier (0.5 - 2.0)
  final double marketDemandMultiplier;

  /// Condition of the item (new, like-new, good, fair, poor)
  final String itemCondition;

  /// Category of the listing (affects depreciation/resale)
  final String category;

  /// Whether the listing has premium features/boost
  final bool isPremium;

  /// Historical price trend (if available)
  final List<double>? priceHistory;

  const ValueAnalysisParams({
    required this.basePrice,
    required this.activeUsers,
    required this.viewCount,
    required this.favoriteCount,
    required this.itemAgeDays,
    this.marketDemandMultiplier = 1.0,
    this.itemCondition = 'good',
    this.category = 'general',
    this.isPremium = false,
    this.priceHistory,
  });
}
