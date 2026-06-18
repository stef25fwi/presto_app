class EligibleResponderForReview {
  const EligibleResponderForReview({
    required this.userId,
    required this.pseudo,
    required this.city,
    required this.photoUrl,
    required this.responseAt,
    required this.conversationId,
  });

  final String userId;
  final String pseudo;
  final String city;
  final String? photoUrl;
  final DateTime? responseAt;
  final String conversationId;

  factory EligibleResponderForReview.fromMap(Map<String, dynamic> data) {
    return EligibleResponderForReview(
      userId: _stringValue(data['userId']),
      pseudo: _stringValue(data['pseudo'], fallback: 'Utilisateur iliprestō'),
      city: _stringValue(data['city']),
      photoUrl: _firstNonEmptyNullableString(
        data,
        const [
          'photoUrl',
          'photoURL',
          'profilePhotoUrl',
          'avatarUrl',
          'imageUrl',
        ],
      ),
      responseAt: _dateFromMillis(data['responseAtMillis']),
      conversationId: _stringValue(data['conversationId']),
    );
  }
}

String? _firstNonEmptyNullableString(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final value = _nullableString(data[key]);
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

class TrustScoreSummary {
  const TrustScoreSummary({
    required this.average,
    required this.communicationAverage,
    required this.punctualityAverage,
    required this.qualityAverage,
    required this.reviewsCount,
    required this.publishedReviewsCount,
    required this.pendingReviewsCount,
    required this.badges,
    required this.paidShowcaseActive,
  });

  final double average;
  final double communicationAverage;
  final double punctualityAverage;
  final double qualityAverage;
  final int reviewsCount;
  final int publishedReviewsCount;
  final int pendingReviewsCount;
  final List<String> badges;
  final bool paidShowcaseActive;

  bool get hasPublishedReviews => publishedReviewsCount > 0;

  factory TrustScoreSummary.empty() {
    return const TrustScoreSummary(
      average: 0,
      communicationAverage: 0,
      punctualityAverage: 0,
      qualityAverage: 0,
      reviewsCount: 0,
      publishedReviewsCount: 0,
      pendingReviewsCount: 0,
      badges: <String>['new_profile'],
      paidShowcaseActive: false,
    );
  }

  factory TrustScoreSummary.fromMap(Map<String, dynamic> data) {
    return TrustScoreSummary(
      average: _doubleValue(data['average']),
      communicationAverage: _doubleValue(data['communicationAverage']),
      punctualityAverage: _doubleValue(data['punctualityAverage']),
      qualityAverage: _doubleValue(data['qualityAverage']),
      reviewsCount: _intValue(data['reviewsCount']),
      publishedReviewsCount: _intValue(data['publishedReviewsCount']),
      pendingReviewsCount: _intValue(data['pendingReviewsCount']),
      badges: _stringList(data['badges']),
      paidShowcaseActive: data['paidShowcaseActive'] == true,
    );
  }
}

class VerifiedReviewPreview {
  const VerifiedReviewPreview({
    required this.reviewId,
    required this.offerTitle,
    required this.averageRating,
    required this.comment,
    required this.createdAt,
  });

  final String reviewId;
  final String offerTitle;
  final double averageRating;
  final String? comment;
  final DateTime? createdAt;

  factory VerifiedReviewPreview.fromMap(Map<String, dynamic> data) {
    return VerifiedReviewPreview(
      reviewId:
          _stringValue(data['id'], fallback: _stringValue(data['reviewId'])),
      offerTitle:
          _stringValue(data['offerTitle'], fallback: 'Annonce iliprestō'),
      averageRating: _doubleValue(data['averageRating']),
      comment: _nullableString(data['comment']),
      createdAt: _dateFromMillis(data['publishedAtMillis']) ??
          _dateFromMillis(data['createdAtMillis']),
    );
  }
}

class TrustScoreProfile {
  const TrustScoreProfile({
    required this.summary,
    required this.latestReviews,
    required this.ratingsPaidShowcaseEnabled,
  });

  final TrustScoreSummary summary;
  final List<VerifiedReviewPreview> latestReviews;
  final bool ratingsPaidShowcaseEnabled;

  factory TrustScoreProfile.fromMap(Map<String, dynamic> data) {
    final rawReviews = data['latestReviews'];
    return TrustScoreProfile(
      summary: TrustScoreSummary.fromMap(_stringMap(data['trustScore'])),
      latestReviews: rawReviews is List
          ? rawReviews
              .map(_stringMap)
              .map(VerifiedReviewPreview.fromMap)
              .toList(growable: false)
          : const <VerifiedReviewPreview>[],
      ratingsPaidShowcaseEnabled: data['ratingsPaidShowcaseEnabled'] == true,
    );
  }
}

class SubmitReviewResult {
  const SubmitReviewResult({
    required this.reviewId,
    required this.status,
    required this.averageRating,
  });

  final String reviewId;
  final String status;
  final double averageRating;

  bool get isPublished => status == 'published';
  bool get isRateLater => status == 'rate_later';

  factory SubmitReviewResult.fromMap(Map<String, dynamic> data) {
    return SubmitReviewResult(
      reviewId: _stringValue(data['reviewId']),
      status: _stringValue(data['status'], fallback: 'pending_moderation'),
      averageRating: _doubleValue(data['averageRating']),
    );
  }
}

Map<String, dynamic> trustScoreStringMap(dynamic value) => _stringMap(value);

String trustScoreRatingText(double value) =>
    value.toStringAsFixed(1).replaceAll('.', ',');

String trustScoreBadgeLabel(String badge) {
  switch (badge) {
    case 'new_profile':
      return 'Nouveau profil';
    case 'first_review_received':
      return 'Premier avis reçu';
    case 'well_rated_profile':
      return 'Profil bien noté';
    case 'top_communication':
      return 'Top communication';
    case 'punctual':
      return 'Ponctuel';
    case 'recommended_quality':
      return 'Qualité recommandée';
    case 'verified_reviews_ilipresto':
      return 'Avis vérifiés iliprestō';
    default:
      return badge.replaceAll('_', ' ');
  }
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, rawValue) => MapEntry(key.toString(), rawValue));
  }
  return const <String, dynamic>{};
}

String _stringValue(dynamic value, {String fallback = ''}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = _stringValue(value);
  return text.isEmpty ? null : text;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((entry) => entry.toString().trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

DateTime? _dateFromMillis(dynamic value) {
  if (value is num && value > 0) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}
