"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const https_1 = require("firebase-functions/v2/https");
const listings_1 = require("./listings");
const media_1 = require("./media");
(0, node_test_1.default)("createListingDraft targets canonical listingDrafts collection", () => {
    strict_1.default.equal((0, listings_1.buildListingDraftDocumentPath)("draft_123"), "listingDrafts/draft_123");
    strict_1.default.notEqual((0, listings_1.buildListingDraftDocumentPath)("draft_123"), "listing_drafts/draft_123");
});
(0, node_test_1.default)("updateListingDraftMedia refuses draft non owner", () => {
    strict_1.default.throws(() => (0, listings_1.assertDraftOwnership)("owner_a", { ownerId: "owner_b" }), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "permission-denied");
        strict_1.default.equal(error.message, "You do not own this draft");
        return true;
    });
});
(0, node_test_1.default)("submitListingDraft refuses category or city not configured", () => {
    strict_1.default.throws(() => (0, listings_1.assertCategoryAndCityConfigured)({
        categoryExists: true,
        categoryActive: true,
        cityExists: false,
        cityActive: false,
    }), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "failed-precondition");
        strict_1.default.equal(error.message, "Category or city is not configured");
        return true;
    });
});
(0, node_test_1.default)("submitListingDraft writes canonical listings/{draftId}", () => {
    strict_1.default.equal((0, listings_1.buildListingDocumentPath)("draft_123"), "listings/draft_123");
});
(0, node_test_1.default)("media final path starts with listings/{uid}/{listingId}/", () => {
    const path = (0, media_1.buildProcessedListingMediaDestinationPath)({
        uid: "user_1",
        listingId: "listing_9",
        storagePath: "listingDrafts/user_1/draft_9/photo.original.jpg",
    });
    strict_1.default.equal(path, "listings/user_1/listing_9/photo.original.webp");
});
(0, node_test_1.default)("listing media output size stays standardized for cards", () => {
    strict_1.default.equal(media_1.STANDARDIZED_LISTING_IMAGE_SIZE, 1200);
});
(0, node_test_1.default)("submitListingDraft delays publication by one minute when photos are present", () => {
    const autoPublishAfter = (0, listings_1.buildAutoPublishAfterForSubmission)({
        mediaCount: 2,
        nowMs: 1_700_000_000_000,
    });
    strict_1.default.ok(autoPublishAfter);
    strict_1.default.equal(autoPublishAfter?.toMillis(), 1_700_000_060_000);
});
(0, node_test_1.default)("submitListingDraft publishes immediately when no photo is present", () => {
    const autoPublishAfter = (0, listings_1.buildAutoPublishAfterForSubmission)({
        mediaCount: 0,
        nowMs: 1_700_000_000_000,
    });
    strict_1.default.equal(autoPublishAfter, null);
});
//# sourceMappingURL=listings.test.js.map