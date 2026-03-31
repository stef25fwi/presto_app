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

test("finalizeListingPublication publishes approved listings when auto-approval is enabled", () => {
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
    autoApproveEnabled: true,
  });

  assert.equal(publication.status, "active");
  assert.equal(publication.moderationStatus, "approved");
  assert.equal(publication.visibility, "public");
  assert.equal(publication.publishedAt, now);
  assert.equal(publication.autoPublishAfter, null);
});

test("finalizeListingPublication delays approved photo listings before publication", () => {
  const now = Symbol("serverTimestamp") as unknown as FirebaseFirestore.FieldValue;
  const autoPublishAfter = Symbol("autoPublishAfter") as unknown as FirebaseFirestore.Timestamp;
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
    autoApproveEnabled: true,
    autoPublishAfter,
  });

  assert.equal(publication.status, "pending");
  assert.equal(publication.moderationStatus, "approved");
  assert.equal(publication.visibility, "private");
  assert.equal(publication.publishedAt, null);
  assert.equal(publication.autoPublishAfter, autoPublishAfter);
});

test("finalizeListingPublication does not delay publication when auto-approval is disabled", () => {
  const now = Symbol("serverTimestamp") as unknown as FirebaseFirestore.FieldValue;
  const autoPublishAfter = Symbol("autoPublishAfter") as unknown as FirebaseFirestore.Timestamp;
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
    autoPublishAfter,
  });

  assert.equal(publication.status, "pending");
  assert.equal(publication.moderationStatus, "pending");
  assert.equal(publication.visibility, "private");
  assert.equal(publication.publishedAt, null);
  assert.equal(publication.autoPublishAfter, null);
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
  assert.equal(publication.autoPublishAfter, null);
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
  assert.equal(publication.autoPublishAfter, null);
});