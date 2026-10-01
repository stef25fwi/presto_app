import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/trust_score/trust_score_models.dart';
import 'package:presto_app/features/trust_score/trust_score_service.dart';
import 'package:presto_app/features/trust_score/trust_score_v2_card.dart';

class _FakeTrustScoreService implements TrustScoreService {
  Future<Map<String, dynamic>> scoreV2Future =
      Future<Map<String, dynamic>>.value(const <String, dynamic>{});
  int scoreV2Calls = 0;

  @override
  Future<void> closeOfferWithReason({
    required String offerId,
    required String reason,
    bool jobDone = false,
  }) async {}

  @override
  Future<List<EligibleResponderForReview>> getEligibleRespondersForReview({
    required String offerId,
  }) async =>
      const <EligibleResponderForReview>[];

  @override
Future<List<Map<String, dynamic>>> getPendingReviewTasks() async =>
    const <Map<String, dynamic>>[];

@override
Future<void> dismissPendingReviewTask({required String offerId}) async {}

@override
Future<String> reviseReview({
  required String reviewId,
  required String comment,
}) async =>
    'pending_peer_review';

  @override
  Future<TrustScoreProfile> getUserTrustScore({required String userId}) async {
    return TrustScoreProfile(
      summary: TrustScoreSummary.empty(),
      latestReviews: const <VerifiedReviewPreview>[],
      ratingsPaidShowcaseEnabled: false,
    );
  }

  @override
  Future<Map<String, dynamic>> getUserTrustScoreV2({
    required String userId,
  }) {
    scoreV2Calls++;
    return scoreV2Future;
  }

  @override
  Future<void> reportReview({
    required String reviewId,
    required String reason,
    String details = '',
  }) async {}

  @override
  Future<String> replyToReview({
    required String reviewId,
    required String replyText,
  }) async =>
      'published';

  @override
  Future<SubmitReviewResult> submitMutualVerifiedReview({
    required String offerId,
    required String reviewedUserId,
    required String reviewerRole,
    required String reviewedRole,
    required Map<String, int> criteria,
    required String comment,
    required bool confirmationChecked,
    bool? wouldRecommend,
    String privateFeedback = '',
  }) async {
    return const SubmitReviewResult(
      reviewId: 'mutual',
      status: 'published',
      averageRating: 5,
    );
  }

  @override
  Future<SubmitReviewResult> submitVerifiedReview({
    required String offerId,
    required String reviewedUserId,
    required int communicationRating,
    required int punctualityRating,
    required int qualityRating,
    required String comment,
    required bool confirmationChecked,
  }) async {
    return const SubmitReviewResult(
      reviewId: 'legacy',
      status: 'published',
      averageRating: 5,
    );
  }
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

Map<String, dynamic> _richData() {
  return <String, dynamic>{
    'trustScoreV2': <String, dynamic>{
      'global': <String, dynamic>{
        'average': '4.7',
        'reviewsCount': '5',
        'score100': '87',
      },
      'provider': <String, dynamic>{
        'average': 4.8,
        'reliableAverage': '4.6',
        'score100': 92,
        'reviewsCount': 3,
        'badges': <dynamic>['top_provider', 'punctual', '', 42],
      },
      'requester': <String, dynamic>{
        'average': 4.4,
        'reliableAverage': 4.2,
        'score100': 79,
        'reviewsCount': 2,
        'badges': <String>['reliable_requester'],
      },
    },
    'latestReviews': <dynamic>[
      <String, dynamic>{
        'id': 'review-1',
        'offerTitle': 'Aide au rangement',
        'averageRating': 4.5,
        'comment': 'Très bonne expérience',
        'replyText': 'Merci beaucoup',
        'reviewerRole': 'requester',
        'reviewedRole': 'provider',
        'roleLabel': 'prestataire',
        'publishedAtMillis': DateTime(2026, 7, 10).millisecondsSinceEpoch,
      },
      <String, dynamic>{
        'reviewId': 'review-2',
        'offerTitle': '',
        'averageRating': '3.5',
        'comment': ' ',
        'replyText': null,
        'reviewerRole': 'provider',
        'reviewedRole': 'requester',
        'createdAtMillis': DateTime(2026, 7, 11).millisecondsSinceEpoch,
      },
      'invalid-entry',
    ],
  };
}

void main() {
  testWidgets('renders loading then the empty trust score state',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final service = _FakeTrustScoreService()..scoreV2Future = completer.future;

    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'user-1', service: service)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const <String, dynamic>{});
    await tester.pumpAndSettle();

    expect(find.text('Score Confiance iliprestō'), findsOneWidget);
    expect(find.text('Nouveau profil'), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);
    expect(find.text('Comme prestataire'), findsOneWidget);
    expect(find.text('Comme annonceur'), findsOneWidget);
    expect(find.text('Aucun avis dans ce rôle.'), findsNWidgets(2));
    expect(find.textContaining('Aucun avis vérifié pour le moment'),
        findsOneWidget);
    expect(service.scoreV2Calls, 1);
  });

  testWidgets('renders a complete global, role and review summary',
      (tester) async {
    final service = _FakeTrustScoreService()
      ..scoreV2Future = Future<Map<String, dynamic>>.value(_richData());

    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'user-2', service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('4,7 / 5'), findsOneWidget);
    expect(find.text('87/100'), findsOneWidget);
    expect(find.textContaining('Basé sur 5 avis vérifiés'), findsOneWidget);
    expect(find.text('4,8 / 5'), findsOneWidget);
    expect(find.textContaining('3 avis · note fiable 4,6 / 5 · 92/100'),
        findsOneWidget);
    expect(find.text('4,4 / 5'), findsOneWidget);
    expect(find.textContaining('2 avis · note fiable 4,2 / 5 · 79/100'),
        findsOneWidget);
    expect(find.text('Top prestataire'), findsOneWidget);
    expect(find.text('Ponctuel'), findsOneWidget);
    expect(find.text('Client fiable'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);

    expect(find.text('Derniers avis vérifiés'), findsOneWidget);
    expect(find.text('4,5 / 5'), findsOneWidget);
    expect(find.text('Aide au rangement'), findsOneWidget);
    expect(find.text('Très bonne expérience'), findsOneWidget);
    expect(find.text('Réponse : Merci beaucoup'), findsOneWidget);
    expect(find.text('10/07/2026'), findsOneWidget);
    expect(find.text('3,5 / 5'), findsOneWidget);
    expect(find.text('Annonce iliprestō'), findsAtLeastNWidgets(1));
    expect(find.text('annonceur'), findsOneWidget);
    expect(find.text('11/07/2026'), findsOneWidget);
  });

  testWidgets('renders an error after an attached future fails',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final service = _FakeTrustScoreService()..scoreV2Future = completer.future;

    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'user-error', service: service)),
    );
    await tester.pump();
    completer.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger les avis.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('refreshes manually and reloads when the user changes',
      (tester) async {
    final service = _FakeTrustScoreService();
    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'user-a', service: service)),
    );
    await tester.pumpAndSettle();
    expect(service.scoreV2Calls, 1);

    service.scoreV2Future = Future<Map<String, dynamic>>.value(_richData());
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();
    expect(service.scoreV2Calls, 2);
    expect(find.text('87/100'), findsOneWidget);

    service.scoreV2Future =
        Future<Map<String, dynamic>>.value(const <String, dynamic>{});
    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'user-b', service: service)),
    );
    await tester.pumpAndSettle();
    expect(service.scoreV2Calls, 3);
    expect(find.text('Nouveau profil'), findsOneWidget);
  });

  testWidgets('reloads when the injected service changes', (tester) async {
    final first = _FakeTrustScoreService();
    final second = _FakeTrustScoreService()
      ..scoreV2Future = Future<Map<String, dynamic>>.value(_richData());

    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'same-user', service: first)),
    );
    await tester.pumpAndSettle();
    expect(first.scoreV2Calls, 1);

    await tester.pumpWidget(
      _host(TrustScoreV2Card(userId: 'same-user', service: second)),
    );
    await tester.pumpAndSettle();
    expect(second.scoreV2Calls, 1);
    expect(find.text('87/100'), findsOneWidget);
  });
}
