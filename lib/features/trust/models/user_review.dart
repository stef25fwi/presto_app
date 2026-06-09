class UserReview {
  const UserReview({
    required this.id,
    required this.offerId,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.reviewType,
    required this.rating,
    required this.comment,
    this.communication,
    this.punctuality,
    this.quality,
    this.budgetRespect,
    this.professionalism,
    this.status = 'published',
  });

  final String id;
  final String offerId;
  final String reviewerId;
  final String reviewedUserId;
  final String reviewType;
  final int rating;
  final String comment;
  final int? communication;
  final int? punctuality;
  final int? quality;
  final int? budgetRespect;
  final int? professionalism;
  final String status;

  bool get isProviderReview => reviewType == 'provider';
  bool get isClientReview => reviewType == 'client';
  bool get isPublished => status == 'published';
  bool get isExcellent => rating >= 5;
  bool get isPositive => rating >= 4;

  factory UserReview.fromMap(String id, Map<String, dynamic> data) {
    return UserReview(
      id: id,
      offerId: data['offerId']?.toString() ?? '',
      reviewerId: data['reviewerId']?.toString() ?? '',
      reviewedUserId: data['reviewedUserId']?.toString() ?? '',
      reviewType: data['reviewType']?.toString() ?? 'provider',
      rating: int.tryParse('${data['rating'] ?? 0}') ?? 0,
      comment: data['comment']?.toString() ?? '',
      communication: int.tryParse('${data['communication'] ?? ''}'),
      punctuality: int.tryParse('${data['punctuality'] ?? ''}'),
      quality: int.tryParse('${data['quality'] ?? ''}'),
      budgetRespect: int.tryParse('${data['budgetRespect'] ?? ''}'),
      professionalism: int.tryParse('${data['professionalism'] ?? ''}'),
      status: data['status']?.toString() ?? 'published',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'offerId': offerId,
      'reviewerId': reviewerId,
      'reviewedUserId': reviewedUserId,
      'reviewType': reviewType,
      'rating': rating,
      'comment': comment,
      'communication': communication,
      'punctuality': punctuality,
      'quality': quality,
      'budgetRespect': budgetRespect,
      'professionalism': professionalism,
      'status': status,
    };
  }
}
