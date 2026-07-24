import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/trust_score/trust_score_service.dart';

typedef _CallableRecord = ({
  String name,
  Duration? timeout,
  dynamic parameters,
});

class _FakeFunctions implements FirebaseFunctions {
  final List<_CallableRecord> calls = <_CallableRecord>[];
  final Map<String, dynamic> responses = <String, dynamic>{};

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    return _FakeCallable(
      owner: this,
      name: name,
      timeout: options?.timeout,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  const _FakeCallable({
    required this.owner,
    required this.name,
    required this.timeout,
  });

  final _FakeFunctions owner;
  final String name;
  final Duration? timeout;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    owner.calls.add((
      name: name,
      timeout: timeout,
      parameters: parameters,
    ));
    return _FakeCallableResult<T>(owner.responses[name] as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallableResult<T> implements HttpsCallableResult<T> {
  const _FakeCallableResult(this.data);

  @override
  final T data;
}

void main() {
  late _FakeFunctions functions;
  late TrustScoreService service;

  setUp(() {
    functions = _FakeFunctions();
    service = TrustScoreService(functions: functions);
  });

  test('clôture une annonce avec le motif et le statut de mission', () async {
    functions.responses['closeOfferWithReason'] = <String, dynamic>{'ok': true};

    await service.closeOfferWithReason(
      offerId: 'offer-1',
      reason: 'mission_done',
      jobDone: true,
    );

    final call = functions.calls.single;
    expect(call.name, 'closeOfferWithReason');
    expect(call.timeout, const Duration(seconds: 30));
    expect(call.parameters, <String, dynamic>{
      'offerId': 'offer-1',
      'reason': 'mission_done',
      'jobDone': true,
    });
  });

  test('filtre et convertit les répondants éligibles', () async {
    functions.responses['getEligibleRespondersForReview'] = <String, dynamic>{
      'responders': <dynamic>[
        <String, dynamic>{
          'userId': ' user-1 ',
          'pseudo': 'Alice',
          'city': 'Baie-Mahault',
          'avatarUrl': 'https://cdn.test/alice.webp',
          'responseAtMillis': 1721779200000,
          'conversationId': 'conversation-1',
        },
        <String, dynamic>{
          'userId': ' ',
          'pseudo': 'Sans identifiant',
        },
        'entrée invalide',
      ],
    };

    final responders = await service.getEligibleRespondersForReview(
      offerId: 'offer-1',
    );

    expect(responders, hasLength(1));
    expect(responders.single.userId, 'user-1');
    expect(responders.single.pseudo, 'Alice');
    expect(responders.single.city, 'Baie-Mahault');
    expect(responders.single.photoUrl, 'https://cdn.test/alice.webp');
    expect(responders.single.conversationId, 'conversation-1');
    expect(responders.single.responseAt, isNotNull);

    final call = functions.calls.single;
    expect(call.name, 'getEligibleRespondersForReview');
    expect(call.timeout, const Duration(seconds: 20));
    expect(call.parameters, <String, dynamic>{'offerId': 'offer-1'});
  });

  test('retourne une liste vide lorsque responders n est pas une liste', () async {
    functions.responses['getEligibleRespondersForReview'] = <String, dynamic>{
      'responders': 'invalid',
    };

    expect(
      await service.getEligibleRespondersForReview(offerId: 'offer-empty'),
      isEmpty,
    );
  });

  test('soumet un avis annonceur avec les trois critères', () async {
    functions.responses['submitMutualVerifiedReview'] = <String, dynamic>{
      'reviewId': 'review-1',
      'status': 'published',
      'averageRating': 4.67,
    };

    final result = await service.submitVerifiedReview(
      offerId: 'offer-1',
      reviewedUserId: 'provider-1',
      communicationRating: 5,
      punctualityRating: 4,
      qualityRating: 5,
      comment: '  Excellent travail  ',
      confirmationChecked: true,
    );

    expect(result.reviewId, 'review-1');
    expect(result.status, 'published');
    expect(result.averageRating, 4.67);
    expect(result.isPublished, isTrue);

    final call = functions.calls.single;
    expect(call.name, 'submitMutualVerifiedReview');
    expect(call.timeout, const Duration(seconds: 30));
    expect(call.parameters, <String, dynamic>{
      'offerId': 'offer-1',
      'reviewedUserId': 'provider-1',
      'reviewerRole': 'requester',
      'reviewedRole': 'provider',
      'criteria': <String, int>{
        'communication': 5,
        'punctuality': 4,
        'quality': 5,
      },
      'comment': 'Excellent travail',
      'privateFeedback': null,
      'confirmationChecked': true,
    });
  });

  test('soumet un avis mutuel avec recommandation et feedback privé', () async {
    functions.responses['submitMutualVerifiedReview'] = <String, dynamic>{
      'reviewId': 'review-2',
      'status': 'pending_peer_review',
      'averageRating': '4.5',
    };

    final result = await service.submitMutualVerifiedReview(
      offerId: 'offer-2',
      reviewedUserId: 'requester-1',
      reviewerRole: 'provider',
      reviewedRole: 'requester',
      criteria: const <String, int>{
        'clarity': 4,
        'communication': 5,
      },
      comment: '   ',
      privateFeedback: '  Informations internes  ',
      wouldRecommend: false,
      confirmationChecked: true,
    );

    expect(result.reviewId, 'review-2');
    expect(result.isPendingPeerReview, isTrue);
    expect(result.averageRating, 4.5);

    expect(functions.calls.single.parameters, <String, dynamic>{
      'offerId': 'offer-2',
      'reviewedUserId': 'requester-1',
      'reviewerRole': 'provider',
      'reviewedRole': 'requester',
      'criteria': <String, int>{
        'clarity': 4,
        'communication': 5,
      },
      'comment': null,
      'privateFeedback': 'Informations internes',
      'wouldRecommend': false,
      'confirmationChecked': true,
    });
  });

  test('convertit le profil de confiance complet', () async {
    functions.responses['getUserTrustScoreV2'] = <String, dynamic>{
      'trustScore': <String, dynamic>{
        'average': 4.8,
        'communicationAverage': 4.9,
        'punctualityAverage': 4.7,
        'qualityAverage': 4.8,
        'reviewsCount': 12,
        'publishedReviewsCount': 10,
        'pendingReviewsCount': 2,
        'badges': <String>['top_provider', 'punctual'],
        'paidShowcaseActive': false,
      },
      'latestReviews': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'review-3',
          'offerTitle': 'Jardinage',
          'averageRating': 5,
          'comment': 'Parfait',
          'reviewerRole': 'requester',
          'reviewedRole': 'provider',
          'publishedAtMillis': 1721779200000,
        },
      ],
      'ratingsPaidShowcaseEnabled': false,
    };

    final profile = await service.getUserTrustScore(userId: 'user-1');

    expect(profile.summary.average, 4.8);
    expect(profile.summary.reviewsCount, 12);
    expect(profile.summary.hasPublishedReviews, isTrue);
    expect(profile.summary.badges, <String>['top_provider', 'punctual']);
    expect(profile.latestReviews, hasLength(1));
    expect(profile.latestReviews.single.reviewId, 'review-3');
    expect(profile.latestReviews.single.roleLabel, 'prestataire');
    expect(profile.ratingsPaidShowcaseEnabled, isFalse);

    final call = functions.calls.single;
    expect(call.name, 'getUserTrustScoreV2');
    expect(call.timeout, const Duration(seconds: 20));
    expect(call.parameters, <String, dynamic>{'userId': 'user-1'});
  });

  test('retourne la map V2 brute même avec des clés non String', () async {
    functions.responses['getUserTrustScoreV2'] = <dynamic, dynamic>{
      7: 'value',
      'average': 4,
    };

    final result = await service.getUserTrustScoreV2(userId: 'user-2');

    expect(result, <String, dynamic>{'7': 'value', 'average': 4});
  });

  test('signale un avis avec détails normalisés ou absents', () async {
    functions.responses['reportReviewV2'] = <String, dynamic>{'ok': true};

    await service.reportReview(
      reviewId: 'review-1',
      reason: 'inappropriate',
      details: '  Contenu problématique  ',
    );
    await service.reportReview(
      reviewId: 'review-2',
      reason: 'spam',
      details: '   ',
    );

    expect(functions.calls, hasLength(2));
    expect(functions.calls.first.name, 'reportReviewV2');
    expect(functions.calls.first.timeout, const Duration(seconds: 20));
    expect(functions.calls.first.parameters, <String, dynamic>{
      'reviewId': 'review-1',
      'reason': 'inappropriate',
      'details': 'Contenu problématique',
    });
    expect(functions.calls.last.parameters, <String, dynamic>{
      'reviewId': 'review-2',
      'reason': 'spam',
      'details': null,
    });
  });

  test('répond à un avis et applique le statut de secours', () async {
    functions.responses['replyToReviewV2'] = <String, dynamic>{
      'status': 'published',
    };

    expect(
      await service.replyToReview(
        reviewId: 'review-1',
        replyText: '  Merci beaucoup  ',
      ),
      'published',
    );
    expect(functions.calls.single.name, 'replyToReviewV2');
    expect(functions.calls.single.timeout, const Duration(seconds: 20));
    expect(functions.calls.single.parameters, <String, dynamic>{
      'reviewId': 'review-1',
      'replyText': 'Merci beaucoup',
    });

    functions.calls.clear();
    functions.responses['replyToReviewV2'] = <String, dynamic>{};
    expect(
      await service.replyToReview(
        reviewId: 'review-2',
        replyText: 'Réponse',
      ),
      'pending_moderation',
    );
  });
}
