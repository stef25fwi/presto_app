import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/trust_score/trust_score_models.dart';

void main() {
  group('EligibleResponderForReview', () {
    test('normalizes aliases, fallback values and response date', () {
      final result = EligibleResponderForReview.fromMap(<String, dynamic>{
        'userId': ' user-1 ',
        'pseudo': ' ',
        'city': ' Pointe-à-Pitre ',
        'profilePhotoUrl': ' https://example.test/photo.jpg ',
        'responseAtMillis': '1700000000000',
        'conversationId': 42,
      });

      expect(result.userId, 'user-1');
      expect(result.pseudo, 'Utilisateur iliprestō');
      expect(result.city, 'Pointe-à-Pitre');
      expect(result.photoUrl, 'https://example.test/photo.jpg');
      expect(result.responseAt,
          DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(result.conversationId, '42');
    });

    test('uses the first non-empty photo alias and accepts empty data', () {
      final withAlias = EligibleResponderForReview.fromMap(<String, dynamic>{
        'photoUrl': ' ',
        'photoURL': '',
        'avatarUrl': ' avatar.png ',
        'imageUrl': 'ignored.png',
      });
      final empty = EligibleResponderForReview.fromMap(const <String, dynamic>{});

      expect(withAlias.photoUrl, 'avatar.png');
      expect(withAlias.responseAt, isNull);
      expect(empty.userId, isEmpty);
      expect(empty.photoUrl, isNull);
      expect(empty.responseAt, isNull);
    });
  });

  group('TrustScoreSummary', () {
    test('empty exposes the new profile baseline', () {
      final summary = TrustScoreSummary.empty();

      expect(summary.average, 0);
      expect(summary.reviewsCount, 0);
      expect(summary.badges, <String>['new_profile']);
      expect(summary.paidShowcaseActive, isFalse);
      expect(summary.hasPublishedReviews, isFalse);
    });

    test('fromMap converts numeric strings, numbers and badge values', () {
      final summary = TrustScoreSummary.fromMap(<String, dynamic>{
        'average': '4.5',
        'communicationAverage': 4,
        'punctualityAverage': '3.75',
        'qualityAverage': 4.9,
        'reviewsCount': '12',
        'publishedReviewsCount': 10.8,
        'pendingReviewsCount': '2',
        'badges': <dynamic>[' top_provider ', '', 7],
        'paidShowcaseActive': true,
      });

      expect(summary.average, 4.5);
      expect(summary.communicationAverage, 4.0);
      expect(summary.punctualityAverage, 3.75);
      expect(summary.qualityAverage, 4.9);
      expect(summary.reviewsCount, 12);
      expect(summary.publishedReviewsCount, 10);
      expect(summary.pendingReviewsCount, 2);
      expect(summary.badges, <String>['top_provider', '7']);
      expect(summary.paidShowcaseActive, isTrue);
      expect(summary.hasPublishedReviews, isTrue);
    });

    test('invalid scalar and badge values fall back safely', () {
      final summary = TrustScoreSummary.fromMap(<String, dynamic>{
        'average': 'not-a-number',
        'reviewsCount': Object(),
        'badges': 'not-a-list',
        'paidShowcaseActive': 1,
      });

      expect(summary.average, 0);
      expect(summary.reviewsCount, 0);
      expect(summary.badges, isEmpty);
      expect(summary.paidShowcaseActive, isFalse);
    });
  });

  group('VerifiedReviewPreview', () {
    test('prefers id, published date and explicit role label', () {
      final review = VerifiedReviewPreview.fromMap(<String, dynamic>{
        'id': ' review-1 ',
        'reviewId': 'legacy-id',
        'offerTitle': ' Jardinage ',
        'averageRating': '4.25',
        'comment': ' Très bien ',
        'replyText': ' Merci ',
        'reviewerRole': 'requester',
        'reviewedRole': 'provider',
        'roleLabel': ' Expert ',
        'publishedAtMillis': 1700000000000,
        'createdAtMillis': 1600000000000,
      });

      expect(review.reviewId, 'review-1');
      expect(review.offerTitle, 'Jardinage');
      expect(review.averageRating, 4.25);
      expect(review.comment, 'Très bien');
      expect(review.replyText, 'Merci');
      expect(review.roleLabel, 'Expert');
      expect(review.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('falls back to legacy id, default title, role and created date', () {
      final requester = VerifiedReviewPreview.fromMap(<String, dynamic>{
        'reviewId': 'legacy',
        'reviewedRole': 'requester',
        'createdAtMillis': '1650000000000',
      });
      final provider = VerifiedReviewPreview.fromMap(<String, dynamic>{
        'reviewedRole': 'provider',
      });

      expect(requester.reviewId, 'legacy');
      expect(requester.offerTitle, 'Annonce iliprestō');
      expect(requester.roleLabel, 'annonceur');
      expect(requester.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1650000000000));
      expect(requester.comment, isNull);
      expect(requester.replyText, isNull);
      expect(provider.roleLabel, 'prestataire');
      expect(provider.createdAt, isNull);
    });
  });

  group('TrustScoreProfile', () {
    test('builds summary and latest reviews from dynamic maps', () {
      final profile = TrustScoreProfile.fromMap(<String, dynamic>{
        'trustScore': <dynamic, dynamic>{
          'average': 4.8,
          'publishedReviewsCount': 1,
        },
        'latestReviews': <dynamic>[
          <dynamic, dynamic>{'id': 'r1', 'averageRating': 5},
          'not-a-map',
        ],
        'ratingsPaidShowcaseEnabled': true,
      });

      expect(profile.summary.average, 4.8);
      expect(profile.summary.hasPublishedReviews, isTrue);
      expect(profile.latestReviews, hasLength(2));
      expect(profile.latestReviews.first.reviewId, 'r1');
      expect(profile.latestReviews.last.reviewId, isEmpty);
      expect(profile.ratingsPaidShowcaseEnabled, isTrue);
    });

    test('uses empty reviews and summary for malformed payloads', () {
      final profile = TrustScoreProfile.fromMap(<String, dynamic>{
        'trustScore': 'invalid',
        'latestReviews': 'invalid',
      });

      expect(profile.summary.average, 0);
      expect(profile.latestReviews, isEmpty);
      expect(profile.ratingsPaidShowcaseEnabled, isFalse);
    });
  });

  group('SubmitReviewResult', () {
    test('maps values and exposes every status helper', () {
      SubmitReviewResult result(String status) => SubmitReviewResult.fromMap(
            <String, dynamic>{
              'reviewId': ' r1 ',
              'status': status,
              'averageRating': '4.0',
            },
          );

      expect(result('published').isPublished, isTrue);
      expect(result('pending_peer_review').isPendingPeerReview, isTrue);
      expect(result('pending_moderation').isPendingModeration, isTrue);
      expect(result('rate_later').isRateLater, isTrue);
      expect(result('published').averageRating, 4.0);
      expect(result('published').reviewId, 'r1');
    });

    test('falls back to pending moderation when status is empty', () {
      final result = SubmitReviewResult.fromMap(const <String, dynamic>{});

      expect(result.status, 'pending_moderation');
      expect(result.isPendingModeration, isTrue);
      expect(result.averageRating, 0);
    });
  });

  group('public trust score helpers', () {
    test('trustScoreStringMap normalizes generic maps and invalid values', () {
      expect(
        trustScoreStringMap(<dynamic, dynamic>{1: 'one'}),
        <String, dynamic>{'1': 'one'},
      );
      expect(trustScoreStringMap('invalid'), isEmpty);
    });

    test('trustScoreRatingText uses one decimal and a comma', () {
      expect(trustScoreRatingText(4), '4,0');
      expect(trustScoreRatingText(4.26), '4,3');
    });

    test('trustScoreBadgeLabel covers canonical and fallback labels', () {
      const expected = <String, String>{
        'new_profile': 'Nouveau profil',
        'first_review_received': 'Premier avis reçu',
        'well_rated_profile': 'Profil bien noté',
        'top_provider': 'Top prestataire',
        'reliable_requester': 'Client fiable',
        'top_communication': 'Top communication',
        'punctual': 'Ponctuel',
        'recommended_quality': 'Qualité recommandée',
        'clear_requester': 'Demande claire',
        'verified_reviews_ilipresto': 'Avis vérifiés iliprestō',
      };

      for (final entry in expected.entries) {
        expect(trustScoreBadgeLabel(entry.key), entry.value);
      }
      expect(trustScoreBadgeLabel('custom_badge'), 'custom badge');
    });
  });
}
