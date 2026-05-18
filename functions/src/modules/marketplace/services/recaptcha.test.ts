import assert from "node:assert/strict";
import test from "node:test";

import {
  shouldRejectListingSubmissionForRecaptcha,
  type RecaptchaVerificationResult,
} from "./recaptcha";

function buildResult(
  overrides: Partial<RecaptchaVerificationResult> = {},
): RecaptchaVerificationResult {
  return {
    allowed: true,
    score: 0.9,
    reasons: [],
    action: "listing_submit",
    tokenValid: true,
    actionMatches: true,
    meetsScoreThreshold: true,
    ...overrides,
  };
}

test("listing submission is rejected when token is invalid", () => {
  assert.equal(
    shouldRejectListingSubmissionForRecaptcha(
      buildResult({
        allowed: false,
        tokenValid: false,
        actionMatches: false,
        meetsScoreThreshold: false,
      }),
    ),
    true,
  );
});

test("listing submission is rejected when action does not match", () => {
  assert.equal(
    shouldRejectListingSubmissionForRecaptcha(
      buildResult({
        allowed: false,
        action: "other_action",
        actionMatches: false,
      }),
    ),
    true,
  );
});

test("listing submission is not rejected solely for low score", () => {
  assert.equal(
    shouldRejectListingSubmissionForRecaptcha(
      buildResult({
        allowed: false,
        score: 0.2,
        meetsScoreThreshold: false,
      }),
    ),
    false,
  );
});