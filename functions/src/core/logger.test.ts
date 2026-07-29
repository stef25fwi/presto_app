import assert from "node:assert/strict";
import test from "node:test";

import { sanitizeLogContext } from "./logger";

test("sanitizeLogContext strips sensitive AI and personal fields recursively", () => {
  const sanitized = sanitizeLogContext({
    requestId: "req-1",
    model: "gpt-test",
    email: "person@example.test",
    nested: {
      prompt: "private prompt",
      audioBase64: "AAAA",
      durationMs: 42,
    },
  });

  assert.deepEqual(sanitized, {
    requestId: "req-1",
    model: "gpt-test",
    nested: { durationMs: 42 },
  });
});

test("sanitizeLogContext bounds oversized strings and arrays", () => {
  const sanitized = sanitizeLogContext({
    safe: "x".repeat(700),
    values: Array.from({ length: 80 }, (_, index) => index),
  });
  assert.match(String(sanitized.safe), /\[TRUNCATED\]$/);
  assert.equal((sanitized.values as unknown[]).length, 50);
});
