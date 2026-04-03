import assert from "node:assert/strict";
import test from "node:test";
import {
  mergeUniqueParticipantIds,
  normalizeParticipantBooleanMap,
  normalizeParticipantNumberMap,
  normalizeParticipantUnknownMap,
  parseCanonicalConversationId,
} from "./repair";

test("parseCanonicalConversationId reads offer and participants from canonical ids", () => {
  assert.deepEqual(
    parseCanonicalConversationId("offer_offer_123__buyer_a__seller_b"),
    {
      offerId: "offer_123",
      participantIds: ["buyer_a", "seller_b"],
    },
  );
});

test("mergeUniqueParticipantIds deduplicates and sorts participant ids", () => {
  assert.deepEqual(
    mergeUniqueParticipantIds(["seller_b", "buyer_a"], ["buyer_a", "", "seller_b"], ["helper_c"]),
    ["buyer_a", "helper_c", "seller_b"],
  );
});

test("normalizeParticipantBooleanMap fills missing participants with false", () => {
  assert.deepEqual(
    normalizeParticipantBooleanMap(["buyer_a", "seller_b"], {seller_b: true}),
    {buyer_a: false, seller_b: true},
  );
});

test("normalizeParticipantNumberMap fills missing participants with zero", () => {
  assert.deepEqual(
    normalizeParticipantNumberMap(["buyer_a", "seller_b"], {seller_b: 2}),
    {buyer_a: 0, seller_b: 2},
  );
});

test("normalizeParticipantUnknownMap keeps only participant scoped keys", () => {
  assert.deepEqual(
    normalizeParticipantUnknownMap(["buyer_a"], {
      buyer_a: "2026-04-03T10:00:00.000Z",
      seller_b: "2026-04-03T11:00:00.000Z",
    }),
    {buyer_a: "2026-04-03T10:00:00.000Z"},
  );
});
