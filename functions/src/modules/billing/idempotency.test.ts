import assert from "node:assert/strict";
import test from "node:test";

import { checkoutIdempotencyBucket, idempotencyKey } from "./callables";
import { evaluateEventLease, shouldApplyStripeEvent } from "./stripe_webhook";

// ── Idempotence sortante : ce que nous envoyons à Stripe ────────────────

test("la même requête produit toujours la même clé", () => {
  const parts = ["checkout", "user_1", "ilipro", 42];
  assert.equal(idempotencyKey(parts), idempotencyKey([...parts]));
});

test("un seul élément différent change la clé", () => {
  const base = idempotencyKey(["checkout", "user_1", "ilipro", 42]);
  assert.notEqual(base, idempotencyKey(["checkout", "user_2", "ilipro", 42]));
  assert.notEqual(base, idempotencyKey(["checkout", "user_1", "ilipresto_plus", 42]));
  assert.notEqual(base, idempotencyKey(["checkout", "user_1", "ilipro", 43]));
});

test("la clé reste dans les limites acceptées par Stripe", () => {
  const key = idempotencyKey(["checkout", "user_1", "ilipro", 42]);
  assert.ok(key.length <= 255, `clé trop longue: ${key.length}`);
  assert.match(key, /^ilipresto_[0-9a-f]{48}$/);
});

test("la clé ne laisse pas fuiter les valeurs d'origine", () => {
  // Un identifiant utilisateur ne doit pas être lisible dans la clé, qui
  // circule en clair dans les en-têtes et les journaux Stripe.
  const key = idempotencyKey(["checkout", "user_secret_42", "ilipro"]);
  assert.equal(key.includes("user_secret_42"), false);
});

test("deux tentatives dans la même fenêtre partagent la clé", () => {
  // Fenêtre fixe et non glissante : les bornes tombent sur les multiples de
  // dix minutes depuis l'époque, d'où le point de départ aligné.
  const windowMs = 10 * 60 * 1000;
  const windowStart = Math.floor(1_000_000_000_000 / windowMs) * windowMs;

  assert.equal(
    checkoutIdempotencyBucket(windowStart),
    checkoutIdempotencyBucket(windowStart + windowMs - 1),
  );
  assert.notEqual(
    checkoutIdempotencyBucket(windowStart),
    checkoutIdempotencyBucket(windowStart + windowMs),
  );
});

test("deux tentatives séparées par une borne ne partagent pas la clé", () => {
  // Conséquence assumée de la fenêtre fixe : deux clics à une minute
  // d'intervalle de part et d'autre d'une borne créent deux sessions
  // Checkout. Sans conséquence — une session non payée expire seule.
  const windowMs = 10 * 60 * 1000;
  const justBeforeBoundary = Math.floor(1_000_000_000_000 / windowMs) * windowMs
    + windowMs - 30_000;

  assert.notEqual(
    checkoutIdempotencyBucket(justBeforeBoundary),
    checkoutIdempotencyBucket(justBeforeBoundary + 60_000),
  );
});

// ── Idempotence entrante : ce que Stripe nous rejoue ────────────────────

test("un événement jamais vu est traité", () => {
  assert.equal(evaluateEventLease(undefined, 1_000), "process");
  assert.equal(evaluateEventLease({}, 1_000), "process");
});

test("un événement déjà traité est un doublon", () => {
  // Stripe rejoue jusqu'au 2xx : le second passage ne doit rien réécrire.
  assert.equal(
    evaluateEventLease({ status: "processed" }, 1_000),
    "duplicate",
  );
});

test("un événement en cours de traitement bloque un traitement concurrent", () => {
  const now = 1_000_000;
  assert.equal(
    evaluateEventLease(
      { status: "processing", processing_started_at_ms: now - 1_000 },
      now,
      60_000,
    ),
    "busy",
  );
});

test("un bail expiré est repris au lieu de bloquer à vie", () => {
  // Cas d'une exécution tuée avant d'avoir libéré son bail : sans expiration,
  // l'événement resterait coincé en « processing » pour toujours.
  const now = 1_000_000;
  assert.equal(
    evaluateEventLease(
      { status: "processing", processing_started_at_ms: now - 120_000 },
      now,
      60_000,
    ),
    "process",
  );
});

test("un bail sans horodatage n'immobilise pas l'événement", () => {
  assert.equal(
    evaluateEventLease({ status: "processing" }, 1_000, 60_000),
    "process",
  );
});

test("un événement en échec est réessayé", () => {
  assert.equal(evaluateEventLease({ status: "failed" }, 1_000), "process");
});

test("un événement plus ancien que l'état enregistré est ignoré", () => {
  // Stripe ne garantit pas l'ordre : `customer.subscription.updated` peut
  // arriver après le `deleted` qui le suit chronologiquement.
  assert.equal(shouldApplyStripeEvent(2_000, 1_999), false);
  assert.equal(shouldApplyStripeEvent(2_000, 2_000), true);
});
