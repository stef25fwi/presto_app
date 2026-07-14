import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/trust_score/trust_score_models.dart';

void main() {
  group('VerifiedReviewPreview V2', () {
    test('normalise les champs, le rôle et la réponse publique', () {
      final review = VerifiedReviewPreview.fromMap(<String, dynamic>{
        'id': ' review-1 ',
        'offerTitle': ' Jardinage ',
        'averageRating': '4.5',
        'comment': ' Travail soigné ',
        'replyText': ' Merci pour votre confiance ',
        'reviewerRole': 'requester',
        'reviewedRole': 'provider',
        'publishedAtMillis': 1720000000000,
      });

      expect(review.reviewId, 'review-1');
      expect(review.offerTitle, 'Jardinage');
      expect(review.averageRating, 4.5);
      expect(review.comment, 'Travail soigné');
      expect(review.replyText, 'Merci pour votre confiance');
      expect(review.reviewerRole, 'requester');
      expect(review.reviewedRole, 'provider');
      expect(review.roleLabel, 'prestataire');
      expect(
        review.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1720000000000),
      );
    });

    test('utilise les fallbacks V1 et annonceur', () {
      final review = VerifiedReviewPreview.fromMap(<String, dynamic>{
        'reviewId': 'legacy-review',
        'reviewedRole': 'requester',
        'createdAtMillis': '1720000001000',
      });

      expect(review.reviewId, 'legacy-review');
      expect(review.offerTitle, 'Annonce iliprestō');
      expect(review.roleLabel, 'annonceur');
      expect(review.comment, isNull);
      expect(review.replyText, isNull);
      expect(
        review.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1720000001000),
      );
    });
  });

  group('SubmitReviewResult V2', () {
    test('expose chaque statut métier', () {
      final published = SubmitReviewResult.fromMap(<String, dynamic>{
        'status': 'published',
      });
      final pendingPeerReview = SubmitReviewResult.fromMap(<String, dynamic>{
        'status': 'pending_peer_review',
      });
      final pendingModeration = SubmitReviewResult.fromMap(<String, dynamic>{
        'status': 'pending_moderation',
      });
      final rateLater = SubmitReviewResult.fromMap(<String, dynamic>{
        'status': 'rate_later',
      });

      expect(published.isPublished, isTrue);
      expect(pendingPeerReview.isPendingPeerReview, isTrue);
      expect(pendingModeration.isPendingModeration, isTrue);
      expect(rateLater.isRateLater, isTrue);
    });

    test('retombe en pending_moderation sur réponse incomplète', () {
      final result = SubmitReviewResult.fromMap(<String, dynamic>{
        'reviewId': 42,
        'averageRating': '3.75',
      });

      expect(result.reviewId, '42');
      expect(result.status, 'pending_moderation');
      expect(result.averageRating, 3.75);
      expect(result.isPendingModeration, isTrue);
    });
  });

  group('TrustScoreProfile V2 compatibility', () {
    test('parse les avis et ignore un latestReviews mal typé', () {
      final profile = TrustScoreProfile.fromMap(<String, dynamic>{
        'trustScore': <String, dynamic>{
          'average': 4.2,
          'reviewsCount': '8',
          'publishedReviewsCount': 7,
          'pendingReviewsCount': 1,
          'badges': <dynamic>['top_provider', '', ' punctual '],
        },
        'latestReviews': <dynamic>[
          <String, dynamic>{
            'id': 'review-2',
            'reviewedRole': 'provider',
          },
        ],
        'ratingsPaidShowcaseEnabled': false,
      });

      expect(profile.summary.average, 4.2);
      expect(profile.summary.reviewsCount, 8);
      expect(profile.summary.publishedReviewsCount, 7);
      expect(profile.summary.pendingReviewsCount, 1);
      expect(
        profile.summary.badges,
        <String>['top_provider', 'punctual'],
      );
      expect(profile.latestReviews, hasLength(1));
      expect(profile.ratingsPaidShowcaseEnabled, isFalse);

      final malformed = TrustScoreProfile.fromMap(<String, dynamic>{
        'latestReviews': 'not-a-list',
      });
      expect(malformed.latestReviews, isEmpty);
    });
  });

  group('Helpers V2', () {
    test('formatte les notes et badges connus', () {
      expect(trustScoreRatingText(4.25), '4,3');
      expect(trustScoreBadgeLabel('reliable_requester'), 'Client fiable');
      expect(trustScoreBadgeLabel('unknown_badge'), 'unknown badge');
    });

    test('normalise les maps avec clés non String', () {
      expect(
        trustScoreStringMap(<dynamic, dynamic>{1: 'one'}),
        <String, dynamic>{'1': 'one'},
      );
      expect(trustScoreStringMap('invalid'), isEmpty);
    });
  });
}
