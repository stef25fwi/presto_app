import assert from "node:assert/strict";
import test from "node:test";

import { buildListingPatchForPhotoReview } from "./admin";

test("buildListingPatchForPhotoReview publishes when the last pending photo is approved", () => {
  const patch = buildListingPatchForPhotoReview({
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

  assert.equal(patch.status, "active");
  assert.equal(patch.visibility, "public");
  assert.equal(patch.moderationStatus, "approved");
  assert.equal(patch.pendingHumanReviewCount, 0);
});

test("buildListingPatchForPhotoReview keeps listing pending while more photos remain", () => {
  const patch = buildListingPatchForPhotoReview({
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

  assert.equal(patch.status, "pending");
  assert.equal(patch.visibility, "private");
  assert.equal(patch.moderationStatus, "manual_review");
  assert.equal(patch.pendingHumanReviewCount, 1);
});

test("buildListingPatchForPhotoReview rejects listing on admin refusal", () => {
  const patch = buildListingPatchForPhotoReview({
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

  assert.equal(patch.status, "rejected");
  assert.equal(patch.visibility, "hidden");
  assert.equal(patch.moderationStatus, "rejected");
  assert.equal(patch.rejectionReason, "Image non conforme");
});