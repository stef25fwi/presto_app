import assert from "node:assert/strict";
import test from "node:test";

import { ValidationError } from "../services/errors";
import {
  validateListingDraftPayload,
  validateListingReportPayload,
} from "./listings";

test("validateListingDraftPayload normalizes a valid listing draft", () => {
  const payload = validateListingDraftPayload({
    title: "Montage meuble cuisine complet",
    description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
    price: "95",
    categoryId: "bricolage-travaux",
    cityId: "97139_les-abymes",
    media: [
      {
        storagePath: "listings/u1/photo.webp",
        downloadUrl: "https://cdn.example/photo.webp",
        mimeType: "image/webp",
      },
    ],
  }, 10);

  assert.equal(payload.price, 95);
  assert.equal(payload.thumbnailUrl, "https://cdn.example/photo.webp");
  assert.equal(payload.media.length, 1);
  assert.ok(payload.searchKeywords.includes("montage"));
  assert.ok(payload.searchKeywords.includes("bricolage"));
  assert.ok(payload.searchKeywords.includes("97139"));
});

test("validateListingDraftPayload reports aggregated issues", () => {
  assert.throws(
    () => validateListingDraftPayload({
      title: "Court",
      description: "Trop court",
      price: -1,
      categoryId: "",
      cityId: "",
      media: [],
    }, 4),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.ok(error.issues.includes("Title must contain at least 10 characters"));
      assert.ok(error.issues.includes("Description must contain at least 30 characters"));
      assert.ok(error.issues.includes("Price must be a positive number"));
      return true;
    },
  );
});

test("validateListingDraftPayload allows publishing without photos", () => {
  const payload = validateListingDraftPayload({
    title: "Montage meuble cuisine complet",
    description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
    price: "95",
    categoryId: "bricolage-travaux",
    cityId: "97139_les-abymes",
    media: [],
  }, 10);

  assert.equal(payload.media.length, 0);
  assert.equal(payload.thumbnailUrl, "");
});

test("validateListingDraftPayload rejects non-webp media", () => {
  assert.throws(
    () => validateListingDraftPayload({
      title: "Montage meuble cuisine complet",
      description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
      price: "95",
      categoryId: "bricolage-travaux",
      cityId: "97139_les-abymes",
      media: [
        {
          storagePath: "listings/u1/photo.jpg",
          downloadUrl: "https://cdn.example/photo.jpg",
          mimeType: "image/jpeg",
        },
      ],
    }, 10),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.ok(error.issues.includes("Photo #1 must be processed as WebP before submission"));
      return true;
    },
  );
});

test("validateListingReportPayload rejects unsupported reason codes", () => {
  assert.throws(
    () => validateListingReportPayload({
      listingId: "listing_123",
      reasonCode: "unknown_reason",
    }),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.deepEqual(error.issues, ["reasonCode is invalid"]);
      return true;
    },
  );
});