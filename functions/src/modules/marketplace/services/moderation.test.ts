import assert from "node:assert/strict";
import test from "node:test";

import {
  computeModerationDecision,
  finalizeListingPublication,
} from "./moderation";

test("computeModerationDecision blocks severe high-risk content", () => {
  const decision = computeModerationDecision({
    riskScore: 82,
    autoFlags: ["adult_content"],
  });

  assert.deepEqual(decision, {
    moderationDecision: "blocked",
    moderationReason: "high_risk_content_detected",
  });
});

test("computeModerationDecision sends duplicates to manual review", () => {
  const decision = computeModerationDecision({
    riskScore: 24,
    autoFlags: ["duplicate_listing"],
  });

  assert.deepEqual(decision, {
    moderationDecision: "manual_review",
    moderationReason: "manual_review_required",
  });
});

test("finalizeListingPublication keeps approved listings private when auto-approval is disabled", () => {
  const now = Symbol("serverTimestamp") as unknown as FirebaseFirestore.FieldValue;
  const publication = finalizeListingPublication({
    evaluation: {
      safeSearchResult: {},
      autoFlags: [],
      riskScore: 12,
      imageScanStatus: "completed",
      textScanStatus: "completed",
      moderationDecision: "approved",
      moderationReason: "approved_automatically",
    },
    now,
    autoApproveEnabled: false,
  });

  assert.equal(publication.status, "pending");
  assert.equal(publication.moderationStatus, "pending");
  assert.equal(publication.visibility, "private");
  assert.equal(publication.publishedAt, null);
});

test("finalizeListingPublication rejects blocked listings", () => {
  const now = Symbol("serverTimestamp") as unknown as FirebaseFirestore.FieldValue;
  const publication = finalizeListingPublication({
    evaluation: {
      safeSearchResult: {},
      autoFlags: ["banned_term"],
      riskScore: 91,
      imageScanStatus: "completed",
      textScanStatus: "completed",
      moderationDecision: "blocked",
      moderationReason: "high_risk_content_detected",
    },
    now,
  });

  assert.equal(publication.status, "rejected");
  assert.equal(publication.moderationStatus, "blocked");
  assert.equal(publication.visibility, "hidden");
  assert.equal(publication.publishedAt, null);
});