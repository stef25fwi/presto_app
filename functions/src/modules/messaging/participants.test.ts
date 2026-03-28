import assert from "node:assert/strict";
import test from "node:test";
import {
  buildConversationParticipantFields,
  readConversationParticipants,
} from "./participants";

test("readConversationParticipants merges current and legacy participant fields", () => {
  const participants = readConversationParticipants({
    participants: ["user_a", "user_b", ""],
    participant_ids: ["user_b", "user_c", null],
  });

  assert.deepEqual(participants, ["user_a", "user_b", "user_c"]);
});

test("buildConversationParticipantFields writes both participant fields", () => {
  const fields = buildConversationParticipantFields(["user_b", "user_a", "user_b"]);

  assert.deepEqual(fields, {
    participants: ["user_b", "user_a"],
    participant_ids: ["user_b", "user_a"],
  });
});