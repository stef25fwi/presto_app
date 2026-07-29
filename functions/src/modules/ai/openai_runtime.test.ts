import assert from "node:assert/strict";
import test from "node:test";

import { classifyOpenAiError } from "./openai_runtime";

test("classifyOpenAiError marks transient rate limits as retryable", () => {
  const result = classifyOpenAiError({
    status: 429,
    code: "rate_limit_exceeded",
    message: "Too many requests",
    request_id: "req_rate",
  });

  assert.equal(result.status, 429);
  assert.equal(result.requestId, "req_rate");
  assert.equal(result.retryable, true);
  assert.equal(result.quotaExhausted, false);
});

test("classifyOpenAiError separates exhausted quota from transient 429", () => {
  const result = classifyOpenAiError({
    status: 429,
    code: "insufficient_quota",
    message: "Insufficient quota for this project",
  });

  assert.equal(result.retryable, false);
  assert.equal(result.quotaExhausted, true);
});

test("classifyOpenAiError recognizes connection timeouts", () => {
  const result = classifyOpenAiError({
    name: "APIConnectionTimeoutError",
    code: "ETIMEDOUT",
    message: "Request timed out",
  });

  assert.equal(result.timeout, true);
  assert.equal(result.retryable, true);
});

test("classifyOpenAiError keeps invalid requests final", () => {
  const result = classifyOpenAiError({
    status: 400,
    code: "invalid_request_error",
    message: "Invalid input",
  });

  assert.equal(result.timeout, false);
  assert.equal(result.retryable, false);
});
