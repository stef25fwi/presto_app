"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const admin_1 = require("./admin");
(0, node_test_1.default)("buildListingPatchForPhotoReview publishes when the last pending photo is approved", () => {
    const patch = (0, admin_1.buildListingPatchForPhotoReview)({
        decision: "approved",
        listingData: {
            imageCount: 2,
            approvedImageCount: 1,
            rejectedImageCount: 0,
            pendingHumanReviewCount: 1,
            pendingReviewImages: ["https://cdn.example/p2.jpg"],
            approvedImageUrls: ["https://cdn.example/p1.jpg"],
            moderation: {
                textStatus: "approved",
            },
        },
        imageUrl: "https://cdn.example/p2.jpg",
        reason: "ok",
    });
    strict_1.default.equal(patch.status, "active");
    strict_1.default.equal(patch.visibility, "public");
    strict_1.default.equal(patch.moderationStatus, "approved");
    strict_1.default.equal(patch.pendingHumanReviewCount, 0);
});
(0, node_test_1.default)("buildListingPatchForPhotoReview keeps listing pending while more photos remain", () => {
    const patch = (0, admin_1.buildListingPatchForPhotoReview)({
        decision: "approved",
        listingData: {
            imageCount: 3,
            approvedImageCount: 1,
            rejectedImageCount: 0,
            pendingHumanReviewCount: 2,
            pendingReviewImages: ["https://cdn.example/p2.jpg", "https://cdn.example/p3.jpg"],
            approvedImageUrls: ["https://cdn.example/p1.jpg"],
            moderation: {
                textStatus: "approved",
            },
        },
        imageUrl: "https://cdn.example/p2.jpg",
        reason: "ok",
    });
    strict_1.default.equal(patch.status, "pending");
    strict_1.default.equal(patch.visibility, "private");
    strict_1.default.equal(patch.moderationStatus, "manual_review");
    strict_1.default.equal(patch.pendingHumanReviewCount, 1);
});
(0, node_test_1.default)("buildListingPatchForPhotoReview rejects listing on admin refusal", () => {
    const patch = (0, admin_1.buildListingPatchForPhotoReview)({
        decision: "rejected",
        listingData: {
            imageCount: 1,
            approvedImageCount: 0,
            rejectedImageCount: 0,
            pendingHumanReviewCount: 1,
            pendingReviewImages: ["https://cdn.example/p1.jpg"],
            rejectedImages: [],
            moderation: {
                textStatus: "approved",
            },
        },
        imageUrl: "https://cdn.example/p1.jpg",
        reason: "Image non conforme",
    });
    strict_1.default.equal(patch.status, "rejected");
    strict_1.default.equal(patch.visibility, "hidden");
    strict_1.default.equal(patch.moderationStatus, "rejected");
    strict_1.default.equal(patch.rejectionReason, "Image non conforme");
});
//# sourceMappingURL=admin.test.js.map