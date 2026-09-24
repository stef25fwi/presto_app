// Test-only Firebase Functions entrypoint.
//
// The production entrypoint intentionally keeps all historical exports. For the
// mutual-review integration test we only load the review V2 module so unrelated
// legacy v1 registrations cannot prevent the Functions Emulator from starting.
// `npm --prefix functions run build` runs before the emulator and produces this
// compiled module.
const reviews = require("../functions/lib/modules/marketplace/callables/reviews_flow_v2.js");

exports.getEligibleRespondersForReviewV2 = reviews.getEligibleRespondersForReviewV2;
exports.getPendingReviewTasksV2 = reviews.getPendingReviewTasksV2;
exports.submitMutualVerifiedReviewComplete = reviews.submitMutualVerifiedReviewComplete;
exports.reviseReviewV2 = reviews.reviseReviewV2;
exports.dismissPendingReviewTaskV2 = reviews.dismissPendingReviewTaskV2;
exports.getUserTrustScoreV2Complete = reviews.getUserTrustScoreV2Complete;
