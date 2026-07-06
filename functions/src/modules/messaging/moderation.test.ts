import assert from "node:assert/strict";
import test from "node:test";
import {
  buildPendingMessagingModeration,
  resolveMessagingModerationRecord,
  shouldModerateSynchronouslyBeforeSend,
} from "./moderation";

test("hidden_until_validated is the only synchronous messaging moderation mode", () => {
  assert.equal(shouldModerateSynchronouslyBeforeSend("hidden_until_validated"), true);
  assert.equal(shouldModerateSynchronouslyBeforeSend("visible_then_retract"), false);
  assert.equal(shouldModerateSynchronouslyBeforeSend("hybrid"), false);
});

test("visible_then_retract only hides blocked content after async moderation", () => {
  assert.deepEqual(
    resolveMessagingModerationRecord({
      mode: "visible_then_retract",
      moderationDecision: "blocked",
    }),
    { status: "rejected", visibility: "hidden" },
  );

  assert.deepEqual(
    resolveMessagingModerationRecord({
      mode: "visible_then_retract",
      moderationDecision: "manual_review",
    }),
    { status: "approved", visibility: "visible" },
  );
});

test("hybrid hides flagged or manual review messaging content", () => {
  assert.deepEqual(
    resolveMessagingModerationRecord({
      mode: "hybrid",
      moderationDecision: "auto_flagged",
    }),
    { status: "manual_review", visibility: "hidden" },
  );

  assert.deepEqual(
    resolveMessagingModerationRecord({
      mode: "hybrid",
      moderationDecision: "approved",
    }),
    { status: "approved", visibility: "visible" },
  );
});

test("pending moderation records stay visible until async resolution", () => {
  assert.deepEqual(buildPendingMessagingModeration("hybrid"), {
    mode: "hybrid",
    status: "pending",
    visibility: "visible",
    moderationDecision: "approved",
    moderationReason: "pending_async_review",
    userMessage: "",
    autoFlags: [],
    riskScore: 0,
    textScanStatus: "pending",
    imageScanStatus: "pending",
  });
});
