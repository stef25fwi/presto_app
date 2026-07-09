import assert from "node:assert/strict";
import test from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import { normalizePayablePlan, resolvePriceIdForPlan } from "./callables";

test("normalizePayablePlan accepts every known ilipresto+ key variant", () => {
  assert.equal(normalizePayablePlan("ilipresto_plus"), "ilipresto_plus");
  assert.equal(normalizePayablePlan("iliprestoplus"), "ilipresto_plus");
  assert.equal(normalizePayablePlan("ilipresto+"), "ilipresto_plus");
});

test("normalizePayablePlan accepts ilipro", () => {
  assert.equal(normalizePayablePlan("ilipro"), "ilipro");
});

test("normalizePayablePlan rejects the free plan and unknown values", () => {
  assert.throws(() => normalizePayablePlan("free"), HttpsError);
  assert.throws(() => normalizePayablePlan("unknown"), HttpsError);
  assert.throws(() => normalizePayablePlan(undefined), HttpsError);
});

test("resolvePriceIdForPlan fails clearly while Stripe price ids are not configured yet", () => {
  // STRIPE_PRICE_ILIPRESTO_PLUS / STRIPE_PRICE_ILIPRO are unset in this test
  // environment (and in production until the Stripe products are created),
  // so this must surface a clear precondition error rather than silently
  // creating a checkout session with an empty price id.
  assert.throws(() => resolvePriceIdForPlan("ilipresto_plus"), HttpsError);
  assert.throws(() => resolvePriceIdForPlan("ilipro"), HttpsError);
});
