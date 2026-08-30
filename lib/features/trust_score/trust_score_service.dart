import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';
import 'trust_score_models.dart';

class TrustScoreService {
  TrustScoreService({FirebaseFunctions? functions})
      : _functions = functions ?? prestoFirebaseFunctions;

  final FirebaseFunctions _functions;

  static const bool ratingsPaidShowcaseEnabled = false;
  static const bool ratingsV2Enabled = true;

  Future<void> closeOfferWithReason({
    required String offerId,
    required String reason,
    bool jobDone = false,
  }) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'closeOfferWithReason',
      timeout: const Duration(seconds: 30),
      parameters: <String, dynamic>{
        'offerId': offerId,
        'reason': reason,
        'jobDone': jobDone,
      },
    );
  }

  Future<List<EligibleResponderForReview>> getEligibleRespondersForReview({
    required String offerId,
  }) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'getEligibleRespondersForReviewV2',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{'offerId': offerId},
    );
    final data = trustScoreStringMap(result.data);
    final rawResponders = data['responders'];
    if (rawResponders is! List) return const <EligibleResponderForReview>[];
    return rawResponders
        .map(trustScoreStringMap)
        .map(EligibleResponderForReview.fromMap)
        .where((entry) => entry.userId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getPendingReviewTasks() async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'getPendingReviewTasksV2',
      timeout: const Duration(seconds: 20),
      parameters: const <String, dynamic>{},
    );
    final data = trustScoreStringMap(result.data);
    final rawTasks = data['tasks'];
    if (rawTasks is! List) return const <Map<String, dynamic>>[];
    return rawTasks
        .map(trustScoreStringMap)
        .where((entry) => (entry['taskId'] ?? '').toString().trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> dismissPendingReviewTask({required String offerId}) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'dismissPendingReviewTaskV2',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{'offerId': offerId},
    );
  }

  Future<String> reviseReview({
    required String reviewId,
    required String comment,
  }) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'reviseReviewV2',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'reviewId': reviewId,
        'comment': comment.trim(),
      },
    );
    return trustScoreStringMap(result.data)['status']?.toString() ??
        'pending_moderation';
  }

  Future<SubmitReviewResult> submitVerifiedReview({
    required String offerId,
    required String reviewedUserId,
    required int communicationRating,
    required int punctualityRating,
    required int qualityRating,
    required String comment,
    required bool confirmationChecked,
  }) async {
    return submitMutualVerifiedReview(
      offerId: offerId,
      reviewedUserId: reviewedUserId,
      reviewerRole: 'requester',
      reviewedRole: 'provider',
      criteria: <String, int>{
        'communication': communicationRating,
        'punctuality': punctualityRating,
        'quality': qualityRating,
      },
      comment: comment,
      confirmationChecked: confirmationChecked,
    );
  }

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
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'submitMutualVerifiedReviewComplete',
      timeout: const Duration(seconds: 30),
      parameters: <String, dynamic>{
        'offerId': offerId,
        'reviewedUserId': reviewedUserId,
        'reviewerRole': reviewerRole,
        'reviewedRole': reviewedRole,
        'criteria': criteria,
        'comment': comment.trim().isEmpty ? null : comment.trim(),
        'privateFeedback': privateFeedback.trim().isEmpty
            ? null
            : privateFeedback.trim(),
        if (wouldRecommend != null) 'wouldRecommend': wouldRecommend,
        'confirmationChecked': confirmationChecked,
      },
    );
    return SubmitReviewResult.fromMap(trustScoreStringMap(result.data));
  }

  Future<TrustScoreProfile> getUserTrustScore({required String userId}) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'getUserTrustScoreV2Complete',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{'userId': userId},
    );
    return TrustScoreProfile.fromMap(trustScoreStringMap(result.data));
  }

  Future<Map<String, dynamic>> getUserTrustScoreV2({
    required String userId,
  }) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'getUserTrustScoreV2Complete',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{'userId': userId},
    );
    return trustScoreStringMap(result.data);
  }

  Future<void> reportReview({
    required String reviewId,
    required String reason,
    String details = '',
  }) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'reportReviewV2',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'reviewId': reviewId,
        'reason': reason,
        'details': details.trim().isEmpty ? null : details.trim(),
      },
    );
  }

  Future<String> replyToReview({
    required String reviewId,
    required String replyText,
  }) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'replyToReviewV2',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        'reviewId': reviewId,
        'replyText': replyText.trim(),
      },
    );
    return trustScoreStringMap(result.data)['status']?.toString() ??
        'pending_moderation';
  }
}
