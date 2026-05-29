import test from "node:test";
import assert from "node:assert/strict";

import { analyzeReviewText, calculateReviewAverage, ratingsPaidShowcaseEnabled } from "./reviews";

test("calculateReviewAverage stores the verified review mean with three decimals", () => {
  assert.equal(calculateReviewAverage(5, 4, 5), 4.667);
  assert.equal(calculateReviewAverage(1, 1, 1), 1);
  assert.equal(calculateReviewAverage(5, 5, 5), 5);
});

test("analyzeReviewText publishes clean optional comments", () => {
  const result = analyzeReviewText("Très bonne communication, mission terminée proprement.");
  assert.equal(result.status, "published");
  assert.equal(result.comment, "Très bonne communication, mission terminée proprement.");
  assert.deepEqual(result.flags, {
    containsPersonalData: false,
    containsInsult: false,
    containsThreat: false,
    containsSuspiciousContent: false,
  });
});

test("analyzeReviewText sends personal data to moderation", () => {
  const result = analyzeReviewText("Contact possible au 06 12 34 56 78 pour confirmer.");
  assert.equal(result.status, "pending_moderation");
  assert.equal(result.flags.containsPersonalData, true);
});

test("ratings paid showcase remains disabled at launch", () => {
  assert.equal(ratingsPaidShowcaseEnabled, false);
});