import 'package:cloud_functions/cloud_functions.dart';

import '../../services/firebase_functions_region.dart';
import 'trust_score_models.dart';

class TrustScoreService {
  TrustScoreService({FirebaseFunctions? functions})
      : _functions = functions ?? prestoFirebaseFunctions;

  final FirebaseFunctions _functions;

  static const bool ratingsPaidShowcaseEnabled = false;

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
      name: 'getEligibleRespondersForReview',
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

  Future<SubmitReviewResult> submitVerifiedReview({
    required String offerId,
    required String reviewedUserId,
    required int communicationRating,
    required int punctualityRating,
    required int qualityRating,
    required String comment,
    required bool confirmationChecked,
  }) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'submitVerifiedReview',
      timeout: const Duration(seconds: 30),
      parameters: <String, dynamic>{
      'offerId': offerId,
      'reviewedUserId': reviewedUserId,
      'communicationRating': communicationRating,
      'punctualityRating': punctualityRating,
      'qualityRating': qualityRating,
      'comment': comment.trim().isEmpty ? null : comment.trim(),
      'confirmationChecked': confirmationChecked,
      },
    );
    return SubmitReviewResult.fromMap(trustScoreStringMap(result.data));
  }

  Future<TrustScoreProfile> getUserTrustScore({required String userId}) async {
    final result = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'getUserTrustScore',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{'userId': userId},
    );
    return TrustScoreProfile.fromMap(trustScoreStringMap(result.data));
  }

  Future<void> reportReview({
    required String reviewId,
    required String reason,
    String details = '',
  }) async {
    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'reportReview',
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
      name: 'replyToReview',
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
