import assert from "node:assert/strict";
import test from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import {
  assertConversationParticipantAccess,
  canonicalConversationId,
  computeUnreadCountAfterMessageDeletion,
  mergeConversationParticipants,
  resolveOfferLikeData,
} from "./callables";
import { readConversationMessageCount } from "./mirror";

test("readConversationMessageCount uses atomic counter when present", () => {
  assert.equal(readConversationMessageCount({ messageCount: 3, lastMessage: "" }), 3);
});

test("readConversationMessageCount falls back to lastMessage for legacy conversations", () => {
  assert.equal(readConversationMessageCount({ lastMessage: "Bonjour" }), 1);
  assert.equal(readConversationMessageCount({ lastMessage: "   " }), 0);
});

test("mergeConversationParticipants preserves legacy ids and injects required participants", () => {
  assert.deepEqual(
    mergeConversationParticipants(["buyer_a"], ["seller_b", "buyer_a"]),
    ["buyer_a", "seller_b"],
  );
});

test("computeUnreadCountAfterMessageDeletion decrements only unread recipients", () => {
  assert.deepEqual(
    computeUnreadCountAfterMessageDeletion({
      participants: ["buyer_a", "seller_b"],
      unreadCount: { buyer_a: 0, seller_b: 2 },
      lastReadAt: {},
      deletedSenderId: "buyer_a",
      deletedCreatedAt: new Date("2026-03-28T10:00:00.000Z"),
    }),
    { buyer_a: 0, seller_b: 1 },
  );
});

test("resolveOfferLikeData prefers listings when both sources exist", () => {
  const result = resolveOfferLikeData({
    offerData: {ownerId: "owner_offer", title: "Offre legacy"},
    listingData: {ownerId: "owner_listing", title: "Listing marketplace"},
  });

  assert.equal(result.source, "listings");
  assert.equal(result.data.ownerId, "owner_listing");
});

test("resolveOfferLikeData falls back to listings when offer is absent", () => {
  const result = resolveOfferLikeData({
    offerData: null,
    listingData: {ownerId: "owner_listing", title: "Listing marketplace"},
  });

  assert.equal(result.source, "listings");
  assert.equal(result.data.ownerId, "owner_listing");
});

test("resolveOfferLikeData falls back to legacy offers only when listing is absent", () => {
  const result = resolveOfferLikeData({
    offerData: {ownerId: "owner_offer", title: "Offre legacy"},
    listingData: null,
  });

  assert.equal(result.source, "offers");
  assert.equal(result.data.ownerId, "owner_offer");
});

test("resolveOfferLikeData throws not-found when neither source exists", () => {
  assert.throws(
    () => resolveOfferLikeData({offerData: null, listingData: null}),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "not-found");
      return true;
    },
  );
});

test("canonicalConversationId is stable and order-independent", () => {
  const left = canonicalConversationId({
    listingId: "listing_123",
    currentUserId: "buyer_a",
    otherUserId: "seller_b",
  });
  const right = canonicalConversationId({
    listingId: "listing_123",
    currentUserId: "seller_b",
    otherUserId: "buyer_a",
  });

  assert.equal(left, right);
  assert.match(left, /^conv_[a-f0-9]{32}$/);
});

test("sendConversationMessage refuses non participant access", () => {
  assert.throws(
    () => assertConversationParticipantAccess(["buyer_a", "seller_b"], "intruder_c"),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "permission-denied");
      assert.equal(error.message, "not allowed to access this conversation");
      return true;
    },
  );
});