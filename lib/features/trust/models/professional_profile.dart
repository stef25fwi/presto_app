class ProfessionalProfile {
  const ProfessionalProfile({
    required this.userId,
    required this.businessName,
    required this.description,
    required this.region,
    required this.department,
    required this.city,
    required this.serviceCategories,
    required this.interventionCities,
    required this.experienceYears,
    this.siret,
    this.siretStatus = 'non_renseigne',
    this.averageRating = 0,
    this.reviewCount = 0,
    this.trustScore = 0,
    this.badges = const [],
    this.portfolioImageUrls = const [],
  });

  final String userId;
  final String businessName;
  final String description;
  final String region;
  final String department;
  final String city;
  final List<String> serviceCategories;
  final List<String> interventionCities;
  final int experienceYears;
  final String? siret;
  final String siretStatus;
  final double averageRating;
  final int reviewCount;
  final int trustScore;
  final List<String> badges;
  final List<String> portfolioImageUrls;

  bool get hasVerifiedSiret => siretStatus == 'valide';
  bool get hasReviews => reviewCount > 0;
  bool get isWellRated => averageRating >= 4.5 && reviewCount >= 3;
  bool get hasPortfolio => portfolioImageUrls.isNotEmpty;

  factory ProfessionalProfile.fromMap(
      String userId, Map<String, dynamic> data) {
    return ProfessionalProfile(
      userId: userId,
      businessName: data['businessName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      region: data['region']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      serviceCategories: List<String>.from(
        data['serviceCategories'] ?? const [],
      ),
      interventionCities: List<String>.from(
        data['interventionCities'] ?? const [],
      ),
      experienceYears: int.tryParse('${data['experienceYears'] ?? 0}') ?? 0,
      siret: data['siret']?.toString(),
      siretStatus: data['siretStatus']?.toString() ?? 'non_renseigne',
      averageRating: double.tryParse('${data['averageRating'] ?? 0}') ?? 0,
      reviewCount: int.tryParse('${data['reviewCount'] ?? 0}') ?? 0,
      trustScore: int.tryParse('${data['trustScore'] ?? 0}') ?? 0,
      badges: List<String>.from(data['badges'] ?? const []),
      portfolioImageUrls: List<String>.from(
        data['portfolioImageUrls'] ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessName': businessName,
      'description': description,
      'region': region,
      'department': department,
      'city': city,
      'serviceCategories': serviceCategories,
      'interventionCities': interventionCities,
      'experienceYears': experienceYears,
      'siret': siret,
      'siretStatus': siretStatus,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'trustScore': trustScore,
      'badges': badges,
      'portfolioImageUrls': portfolioImageUrls,
    };
  }
}
