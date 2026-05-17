import assert from "node:assert/strict";
import test from "node:test";
import { HttpsError } from "firebase-functions/v2/https";

import {
  assertCategoryAndCityConfigured,
  assertDraftOwnership,
  buildListingDocumentPath,
  buildListingDraftDocumentPath,
} from "./listings";
import { buildProcessedListingMediaDestinationPath } from "./media";

test("createListingDraft targets canonical listingDrafts collection", () => {
  assert.equal(buildListingDraftDocumentPath("draft_123"), "listingDrafts/draft_123");
  assert.notEqual(buildListingDraftDocumentPath("draft_123"), "listing_drafts/draft_123");
});

test("updateListingDraftMedia refuses draft non owner", () => {
  assert.throws(
    () => assertDraftOwnership("owner_a", { ownerId: "owner_b" }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "permission-denied");
      assert.equal(error.message, "You do not own this draft");
      return true;
    },
  );
});

test("submitListingDraft refuses category or city not configured", () => {
  assert.throws(
    () => assertCategoryAndCityConfigured({
      categoryExists: true,
      categoryActive: true,
      cityExists: false,
      cityActive: false,
    }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "failed-precondition");
      assert.equal(error.message, "Category or city is not configured");
      return true;
    },
  );
});

test("submitListingDraft writes canonical listings/{draftId}", () => {
  assert.equal(buildListingDocumentPath("draft_123"), "listings/draft_123");
});

test("media final path starts with listings/{uid}/{listingId}/", () => {
  const path = buildProcessedListingMediaDestinationPath({
    uid: "user_1",
    listingId: "listing_9",
    storagePath: "listingDrafts/user_1/draft_9/photo.original.jpg",
  });

  assert.equal(path, "listings/user_1/listing_9/photo.original.webp");
});