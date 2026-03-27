import assert from "node:assert/strict";
import test from "node:test";
import {
  computeConversationStatus,
  isConversationBlocked,
  isConversationFlagEnabledForUser,
  readConversationFlagMap,
} from "./state";

test("readConversationFlagMap normalizes boolean maps", () => {
  const flags = readConversationFlagMap({
    archivedBy: {
      a: true,
      b: false,
      c: "yes",
    },
  }, "archivedBy");

  assert.deepEqual(flags, {
    a: true,
    b: false,
    c: false,
  });
});

test("computeConversationStatus returns open when nobody archived or blocked", () => {
  const status = computeConversationStatus(["a", "b"], { a: false, b: false }, { a: false, b: false });

  assert.equal(status, "open");
});

test("computeConversationStatus returns archived when all participants archived", () => {
  const status = computeConversationStatus(["a", "b"], { a: true, b: true }, { a: false, b: false });

  assert.equal(status, "archived");
});

test("computeConversationStatus returns closed when any participant blocked", () => {
  const status = computeConversationStatus(["a", "b"], { a: true, b: true }, { a: false, b: true });

  assert.equal(status, "closed");
  assert.equal(isConversationBlocked({ blockedBy: { a: false, b: true } }), true);
});

test("isConversationFlagEnabledForUser reads participant-specific flags", () => {
  const data = {
    blockedBy: {
      a: false,
      b: true,
    },
  };

  assert.equal(isConversationFlagEnabledForUser(data, "blockedBy", "a"), false);
  assert.equal(isConversationFlagEnabledForUser(data, "blockedBy", "b"), true);
});