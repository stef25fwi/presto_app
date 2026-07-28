import assert from "node:assert/strict";
import test from "node:test";

import { ValidationError } from "../services/errors";
import {
  validateConversationReportPayload,
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
    category: "Bricolage / Travaux",
    city: "Les Abymes",
    location: "Les Abymes",
    postalCode: "97139",
    cp: "97139",
    dept: "971",
    region: "01",
    cityCategoryKey: "97139_les-abymes_bricolage-travaux",
    budgetValue: 95,
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
  assert.equal("width" in payload.media[0]!, false);
  assert.equal("height" in payload.media[0]!, false);
  assert.equal("sizeBytes" in payload.media[0]!, false);
  assert.equal(payload.city, "Les Abymes");
  assert.equal(payload.postalCode, "97139");
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

test("validateListingDraftPayload accepts raw image formats for backend conversion", () => {
  const payload = validateListingDraftPayload({
    title: "Montage meuble cuisine complet",
    description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
    price: "95",
    categoryId: "bricolage-travaux",
    cityId: "97139_les-abymes",
    media: [
      {
        storagePath: "listingDrafts/u1/draft_1/photo.jpg",
        downloadUrl: "https://cdn.example/photo.jpg",
        mimeType: "image/jpeg",
      },
    ],
  }, 10);

  assert.equal(payload.media.length, 1);
  assert.equal(payload.media[0]?.mimeType, "image/jpeg");
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

test("validateConversationReportPayload normalizes a valid report", () => {
  const payload = validateConversationReportPayload({
    conversationId: "offer_listing_123__uidA__uidB",
    messageId: " msg_1 ",
    reasonCode: "harassment",
    reasonText: "  Propos déplacés répétés  ",
  });

  assert.equal(payload.conversationId, "offer_listing_123__uidA__uidB");
  assert.equal(payload.messageId, "msg_1");
  assert.equal(payload.reasonCode, "harassment");
  assert.equal(payload.reasonText, "Propos déplacés répétés");
});

test("validateConversationReportPayload allows an omitted messageId", () => {
  const payload = validateConversationReportPayload({
    conversationId: "offer_listing_123__uidA__uidB",
    reasonCode: "spam",
  });

  assert.equal(payload.messageId, undefined);
  assert.equal(payload.reasonText, undefined);
});

test("validateConversationReportPayload rejects a missing conversationId", () => {
  assert.throws(
    () => validateConversationReportPayload({
      reasonCode: "spam",
    }),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.deepEqual(error.issues, ["conversationId is required"]);
      return true;
    },
  );
});

test("validateConversationReportPayload rejects unsupported reason codes", () => {
  assert.throws(
    () => validateConversationReportPayload({
      conversationId: "offer_listing_123__uidA__uidB",
      reasonCode: "wrong_category",
    }),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.deepEqual(error.issues, ["reasonCode is invalid"]);
      return true;
    },
  );
});

test("validateConversationReportPayload rejects an over-long reasonText", () => {
  assert.throws(
    () => validateConversationReportPayload({
      conversationId: "offer_listing_123__uidA__uidB",
      reasonCode: "other",
      reasonText: "x".repeat(801),
    }),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.deepEqual(error.issues, ["reasonText is too long"]);
      return true;
    },
  );
});