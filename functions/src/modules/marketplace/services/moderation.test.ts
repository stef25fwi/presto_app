import assert from "node:assert/strict";
import test from "node:test";

import {
  buildListingMediaModerationState,
  buildListingPhotoReviewDocs,
  buildModerationUserMessage,
  computeModerationDecision,
  finalizeListingPublication,
  resolveModerationImageUri,
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

test("computeModerationDecision blocks severe content even before publication", () => {
  const decision = computeModerationDecision({
    riskScore: 25,
    autoFlags: ["banned_term"],
  });

  assert.deepEqual(decision, {
    moderationDecision: "blocked",
    moderationReason: "high_risk_content_detected",
  });
});

test("buildModerationUserMessage asks the user to check CGU compliance", () => {
  const message = buildModerationUserMessage({
    autoFlags: ["adult_content"],
    moderationReason: "high_risk_content_detected",
  });

  assert.match(message, /refusee/);
  assert.match(message, /CGU/);
  assert.match(message, /texte et les images/);
});

test("buildModerationUserMessage stays empty for approved listings", () => {
  const message = buildModerationUserMessage({
    autoFlags: [],
    moderationReason: "approved_automatically",
  });

  assert.equal(message, "");
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

test("finalizeListingPublication keeps auto-flagged listings private even with auto-approval", () => {
  const now = Symbol("serverTimestamp") as unknown as FirebaseFirestore.FieldValue;
  const publication = finalizeListingPublication({
    evaluation: {
      safeSearchResult: {},
      autoFlags: ["suspicious_text"],
      riskScore: 42,
      imageScanStatus: "completed",
      textScanStatus: "completed",
      moderationDecision: "auto_flagged",
      moderationReason: "risk_threshold_exceeded",
    },
    now,
    autoApproveEnabled: true,
  });

  assert.equal(publication.status, "pending");
  assert.equal(publication.moderationStatus, "auto_flagged");
  assert.equal(publication.visibility, "private");
  assert.equal(publication.publishedAt, null);
  assert.equal(publication.autoPublishAfter, null);
});

test("finalizeListingPublication keeps manual-review listings private even with auto-approval", () => {
  const now = Symbol("serverTimestamp") as unknown as FirebaseFirestore.FieldValue;
  const publication = finalizeListingPublication({
    evaluation: {
      safeSearchResult: {},
      autoFlags: ["duplicate_listing"],
      riskScore: 58,
      imageScanStatus: "completed",
      textScanStatus: "completed",
      moderationDecision: "manual_review",
      moderationReason: "manual_review_required",
    },
    now,
    autoApproveEnabled: true,
  });

  assert.equal(publication.status, "pending");
  assert.equal(publication.moderationStatus, "manual_review");
  assert.equal(publication.visibility, "private");
  assert.equal(publication.publishedAt, null);
  assert.equal(publication.autoPublishAfter, null);
});

test("buildListingMediaModerationState tracks pending human review images", () => {
  const state = buildListingMediaModerationState({
    media: [
      {
        storagePath: "listingDrafts/u1/d1/photo-1.jpg",
        downloadUrl: "https://cdn.example/photo-1.jpg",
      },
      {
        storagePath: "listingDrafts/u1/d1/photo-2.jpg",
        downloadUrl: "https://cdn.example/photo-2.jpg",
      },
    ],
    evaluation: {
      safeSearchResult: { provider: "google_vision_safe_search" },
      autoFlags: ["suspicious_text"],
      riskScore: 61,
      imageScanStatus: "completed",
      textScanStatus: "completed",
      moderationDecision: "manual_review",
      moderationReason: "manual_review_required",
      moderationUserMessage: "Votre annonce est en attente de verification par l'equipe ilipresto avant publication.",
    },
  });

  assert.equal(state.imageCount, 2);
  assert.equal(state.pendingHumanReviewCount, 2);
  assert.deepEqual(state.pendingReviewImages, [
    "https://cdn.example/photo-1.jpg",
    "https://cdn.example/photo-2.jpg",
  ]);
});

test("buildListingPhotoReviewDocs creates one pending review per image", () => {
  const docs = buildListingPhotoReviewDocs({
    listingId: "listing_123",
    ownerId: "user_123",
    media: [
      {
        storagePath: "listingDrafts/user_123/draft_123/photo-1.jpg",
        downloadUrl: "https://cdn.example/photo-1.jpg",
        thumbnailUrl: "https://cdn.example/photo-1-thumb.jpg",
      },
    ],
    evaluation: {
      safeSearchResult: { provider: "google_vision_safe_search", summary: { adult: "POSSIBLE" } },
      autoFlags: ["suspicious_text"],
      riskScore: 58,
      imageScanStatus: "completed",
      textScanStatus: "completed",
      moderationDecision: "manual_review",
      moderationReason: "manual_review_required",
      moderationUserMessage: "Votre annonce est en attente de verification par l'equipe ilipresto avant publication.",
    },
  });

  assert.equal(docs.length, 1);
  assert.equal(docs[0]?.id, "listing_123_1");
  assert.equal(docs[0]?.status, "pending");
  assert.equal(docs[0]?.storagePath, "listingDrafts/user_123/draft_123/photo-1.jpg");
  assert.equal(docs[0]?.imageUrl, "https://cdn.example/photo-1.jpg");
});
test("resolveModerationImageUri préfixe un chemin relatif avec le bucket du projet", () => {
  assert.equal(
    resolveModerationImageUri("listings/abc/photo.jpg", "presto-app-74abe.appspot.com"),
    "gs://presto-app-74abe.appspot.com/listings/abc/photo.jpg",
  );
});

test("resolveModerationImageUri accepte un gs:// désignant le bucket du projet", () => {
  assert.equal(
    resolveModerationImageUri(
      "gs://presto-app-74abe.appspot.com/listings/abc/photo.jpg",
      "presto-app-74abe.appspot.com",
    ),
    "gs://presto-app-74abe.appspot.com/listings/abc/photo.jpg",
  );
});

test("resolveModerationImageUri refuse un bucket tiers fourni par le client", () => {
  assert.throws(
    () =>
      resolveModerationImageUri(
        "gs://bucket-attaquant/photo.jpg",
        "presto-app-74abe.appspot.com",
      ),
    /Bucket de modération non autorisé : bucket-attaquant/,
  );
});

test("resolveModerationImageUri refuse une remontée de chemin ou un chemin absolu", () => {
  assert.throws(
    () => resolveModerationImageUri("../../etc/passwd", "bucket"),
    /storagePath de modération invalide/,
  );
  assert.throws(
    () => resolveModerationImageUri("/listings/a.jpg", "bucket"),
    /storagePath de modération invalide/,
  );
});

test("resolveModerationImageUri refuse un storagePath vide", () => {
  assert.throws(
    () => resolveModerationImageUri("   ", "bucket"),
    /storagePath de modération vide/,
  );
});
