import assert from "node:assert/strict";
import test from "node:test";

import {
  checkoutIdempotencyBucket,
  checkoutSuccessUrl,
  isBlockingSubscriptionStatus,
  normalizePlan,
} from "./callables";

test("normalise les deux plans payants", () => {
  assert.equal(normalizePlan("ilipresto+"), "ilipresto_plus");
  assert.equal(normalizePlan("ilipresto_plus"), "ilipresto_plus");
  assert.equal(normalizePlan("ilipro"), "ilipro");
});

test("utilise une fenêtre idempotente de dix minutes", () => {
  assert.equal(checkoutIdempotencyBucket(0), 0);
  assert.equal(checkoutIdempotencyBucket(599_999), 0);
  assert.equal(checkoutIdempotencyBucket(600_000), 1);
});

test("bloque la création d'un second abonnement actif ou impayé", () => {
  for (const status of [
    "active",
    "trialing",
    "past_due",
    "unpaid",
    "incomplete",
    "paused",
  ]) {
    assert.equal(isBlockingSubscriptionStatus(status), true, status);
  }
  assert.equal(isBlockingSubscriptionStatus("canceled"), false);
  assert.equal(isBlockingSubscriptionStatus("incomplete_expired"), false);
});

test("l'URL de succès conserve l'identifiant de session Stripe", () => {
  const previous = process.env.STRIPE_SUCCESS_URL;
  delete process.env.STRIPE_SUCCESS_URL;
  try {
    const url = checkoutSuccessUrl();
    assert.match(url, /^https:\/\/ilipresto\.web\.app\/account\?/);
    assert.match(url, /section=subscriptions/);
    assert.match(url, /subscription=success/);
    assert.match(url, /session_id=\{CHECKOUT_SESSION_ID\}/);
  } finally {
    if (previous === undefined) {
      delete process.env.STRIPE_SUCCESS_URL;
    } else {
      process.env.STRIPE_SUCCESS_URL = previous;
    }
  }
});
