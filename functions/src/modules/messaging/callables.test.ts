import assert from "node:assert/strict";
import test from "node:test";
import { readConversationMessageCount } from "./callables";

test("readConversationMessageCount uses atomic counter when present", () => {
  assert.equal(readConversationMessageCount({ messageCount: 3, lastMessage: "" }), 3);
});

test("readConversationMessageCount falls back to lastMessage for legacy conversations", () => {
  assert.equal(readConversationMessageCount({ lastMessage: "Bonjour" }), 1);
  assert.equal(readConversationMessageCount({ lastMessage: "   " }), 0);
});