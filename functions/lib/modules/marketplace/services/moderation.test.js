"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const moderation_1 = require("./moderation");
(0, node_test_1.default)("computeModerationDecision blocks severe high-risk content", () => {
    const decision = (0, moderation_1.computeModerationDecision)({
        riskScore: 82,
        autoFlags: ["adult_content"],
    });
    strict_1.default.deepEqual(decision, {
        moderationDecision: "blocked",
        moderationReason: "high_risk_content_detected",
    });
});
(0, node_test_1.default)("computeModerationDecision blocks severe content even before publication", () => {
    const decision = (0, moderation_1.computeModerationDecision)({
        riskScore: 25,
        autoFlags: ["banned_term"],
    });
    strict_1.default.deepEqual(decision, {
        moderationDecision: "blocked",
        moderationReason: "high_risk_content_detected",
    });
});
(0, node_test_1.default)("buildModerationUserMessage asks the user to check CGU compliance", () => {
    const message = (0, moderation_1.buildModerationUserMessage)({
        autoFlags: ["adult_content"],
        moderationReason: "high_risk_content_detected",
    });
    strict_1.default.match(message, /refusee/);
    strict_1.default.match(message, /CGU/);
    strict_1.default.match(message, /texte et les images/);
});
(0, node_test_1.default)("buildModerationUserMessage stays empty for approved listings", () => {
    const message = (0, moderation_1.buildModerationUserMessage)({
        autoFlags: [],
        moderationReason: "approved_automatically",
    });
    strict_1.default.equal(message, "");
});
(0, node_test_1.default)("computeModerationDecision sends duplicates to manual review", () => {
    const decision = (0, moderation_1.computeModerationDecision)({
        riskScore: 24,
        autoFlags: ["duplicate_listing"],
    });
    strict_1.default.deepEqual(decision, {
        moderationDecision: "manual_review",
        moderationReason: "manual_review_required",
    });
});
(0, node_test_1.default)("finalizeListingPublication publishes approved listings when auto-approval is enabled", () => {
    const now = Symbol("serverTimestamp");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "active");
    strict_1.default.equal(publication.moderationStatus, "approved");
    strict_1.default.equal(publication.visibility, "public");
    strict_1.default.equal(publication.publishedAt, now);
    strict_1.default.equal(publication.autoPublishAfter, null);
});
(0, node_test_1.default)("finalizeListingPublication delays approved photo listings before publication", () => {
    const now = Symbol("serverTimestamp");
    const autoPublishAfter = Symbol("autoPublishAfter");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "pending");
    strict_1.default.equal(publication.moderationStatus, "approved");
    strict_1.default.equal(publication.visibility, "private");
    strict_1.default.equal(publication.publishedAt, null);
    strict_1.default.equal(publication.autoPublishAfter, autoPublishAfter);
});
(0, node_test_1.default)("finalizeListingPublication does not delay publication when auto-approval is disabled", () => {
    const now = Symbol("serverTimestamp");
    const autoPublishAfter = Symbol("autoPublishAfter");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "pending");
    strict_1.default.equal(publication.moderationStatus, "pending");
    strict_1.default.equal(publication.visibility, "private");
    strict_1.default.equal(publication.publishedAt, null);
    strict_1.default.equal(publication.autoPublishAfter, null);
});
(0, node_test_1.default)("finalizeListingPublication keeps approved listings private when auto-approval is disabled", () => {
    const now = Symbol("serverTimestamp");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "pending");
    strict_1.default.equal(publication.moderationStatus, "pending");
    strict_1.default.equal(publication.visibility, "private");
    strict_1.default.equal(publication.publishedAt, null);
    strict_1.default.equal(publication.autoPublishAfter, null);
});
(0, node_test_1.default)("finalizeListingPublication rejects blocked listings", () => {
    const now = Symbol("serverTimestamp");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "rejected");
    strict_1.default.equal(publication.moderationStatus, "blocked");
    strict_1.default.equal(publication.visibility, "hidden");
    strict_1.default.equal(publication.publishedAt, null);
    strict_1.default.equal(publication.autoPublishAfter, null);
});
(0, node_test_1.default)("finalizeListingPublication keeps auto-flagged listings private even with auto-approval", () => {
    const now = Symbol("serverTimestamp");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "pending");
    strict_1.default.equal(publication.moderationStatus, "auto_flagged");
    strict_1.default.equal(publication.visibility, "private");
    strict_1.default.equal(publication.publishedAt, null);
    strict_1.default.equal(publication.autoPublishAfter, null);
});
(0, node_test_1.default)("finalizeListingPublication keeps manual-review listings private even with auto-approval", () => {
    const now = Symbol("serverTimestamp");
    const publication = (0, moderation_1.finalizeListingPublication)({
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
    strict_1.default.equal(publication.status, "pending");
    strict_1.default.equal(publication.moderationStatus, "manual_review");
    strict_1.default.equal(publication.visibility, "private");
    strict_1.default.equal(publication.publishedAt, null);
    strict_1.default.equal(publication.autoPublishAfter, null);
});
(0, node_test_1.default)("buildListingMediaModerationState tracks pending human review images", () => {
    const state = (0, moderation_1.buildListingMediaModerationState)({
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
    strict_1.default.equal(state.imageCount, 2);
    strict_1.default.equal(state.pendingHumanReviewCount, 2);
    strict_1.default.deepEqual(state.pendingReviewImages, [
        "https://cdn.example/photo-1.jpg",
        "https://cdn.example/photo-2.jpg",
    ]);
});
(0, node_test_1.default)("buildListingPhotoReviewDocs creates one pending review per image", () => {
    const docs = (0, moderation_1.buildListingPhotoReviewDocs)({
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
    strict_1.default.equal(docs.length, 1);
    strict_1.default.equal(docs[0]?.id, "listing_123_1");
    strict_1.default.equal(docs[0]?.status, "pending");
    strict_1.default.equal(docs[0]?.storagePath, "listingDrafts/user_123/draft_123/photo-1.jpg");
    strict_1.default.equal(docs[0]?.imageUrl, "https://cdn.example/photo-1.jpg");
});
(0, node_test_1.default)("resolveModerationImageUri préfixe un chemin relatif avec le bucket du projet", () => {
    strict_1.default.equal((0, moderation_1.resolveModerationImageUri)("listings/abc/photo.jpg", "presto-app-74abe.appspot.com"), "gs://presto-app-74abe.appspot.com/listings/abc/photo.jpg");
});
(0, node_test_1.default)("resolveModerationImageUri accepte un gs:// désignant le bucket du projet", () => {
    strict_1.default.equal((0, moderation_1.resolveModerationImageUri)("gs://presto-app-74abe.appspot.com/listings/abc/photo.jpg", "presto-app-74abe.appspot.com"), "gs://presto-app-74abe.appspot.com/listings/abc/photo.jpg");
});
(0, node_test_1.default)("resolveModerationImageUri refuse un bucket tiers fourni par le client", () => {
    strict_1.default.throws(() => (0, moderation_1.resolveModerationImageUri)("gs://bucket-attaquant/photo.jpg", "presto-app-74abe.appspot.com"), /Bucket de modération non autorisé : bucket-attaquant/);
});
(0, node_test_1.default)("resolveModerationImageUri refuse une remontée de chemin ou un chemin absolu", () => {
    strict_1.default.throws(() => (0, moderation_1.resolveModerationImageUri)("../../etc/passwd", "bucket"), /storagePath de modération invalide/);
    strict_1.default.throws(() => (0, moderation_1.resolveModerationImageUri)("/listings/a.jpg", "bucket"), /storagePath de modération invalide/);
});
(0, node_test_1.default)("resolveModerationImageUri refuse un storagePath vide", () => {
    strict_1.default.throws(() => (0, moderation_1.resolveModerationImageUri)("   ", "bucket"), /storagePath de modération vide/);
});
//# sourceMappingURL=moderation.test.js.map