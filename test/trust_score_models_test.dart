import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/trust_score/trust_score_models.dart';
import 'package:presto_app/features/trust_score/trust_score_service.dart';

void main() {
  test('TrustScoreSummary parses aggregate ratings and badges', () {
    final summary = TrustScoreSummary.fromMap(const <String, dynamic>{
      'average': 4.666,
      'communicationAverage': 4.8,
      'punctualityAverage': 4.5,
      'qualityAverage': 4.7,
      'reviewsCount': 12,
      'publishedReviewsCount': 12,
      'pendingReviewsCount': 1,
      'badges': <String>['verified_reviews_ilipresto', 'top_communication'],
    });

    expect(summary.hasPublishedReviews, isTrue);
    expect(trustScoreRatingText(summary.average), '4,7');
    expect(summary.badges.map(trustScoreBadgeLabel),
        contains('Avis vérifiés iliprestō'));
  });

  test('EligibleResponderForReview parses responder proof date', () {
    final responder = EligibleResponderForReview.fromMap(<String, dynamic>{
      'userId': 'user-1',
      'pseudo': 'Mina',
      'city': 'Baie-Mahault',
      'responseAtMillis': 1710000000000,
      'conversationId': 'offer_listing__owner__user-1',
    });

    expect(responder.userId, 'user-1');
    expect(responder.pseudo, 'Mina');
    expect(responder.responseAt, isNotNull);
  });

  test('TrustScoreProfile keeps paid showcase disabled by default', () {
    final profile = TrustScoreProfile.fromMap(const <String, dynamic>{
      'ratingsPaidShowcaseEnabled': false,
      'trustScore': <String, dynamic>{
        'average': 5,
        'publishedReviewsCount': 1,
      },
      'latestReviews': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'review-1',
          'offerTitle': 'Service traiteur',
          'averageRating': 5,
          'comment': 'Très fiable.',
        },
      ],
    });

    expect(TrustScoreService.ratingsPaidShowcaseEnabled, isFalse);
    expect(profile.ratingsPaidShowcaseEnabled, isFalse);
    expect(profile.latestReviews, hasLength(1));
  });
}
