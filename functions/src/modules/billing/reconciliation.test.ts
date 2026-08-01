import assert from "node:assert/strict";
import test from "node:test";

import { diffSubscriptionRecord, summarize } from "./reconciliation";

const stripeSubscription = {
  id: "sub_123",
  status: "active",
  cancel_at_period_end: false,
  current_period_end: 1_800_000_000,
  items: { data: [{ price: { id: "price_plus" } }] },
};

const storedSubscription = {
  status: "active",
  cancel_at_period_end: false,
  current_period_end: 1_800_000_000_000,
  stripe_price_id: "price_plus",
};

test("un abonnement identique ne produit aucune divergence", () => {
  assert.deepEqual(
    diffSubscriptionRecord(stripeSubscription, storedSubscription),
    [],
  );
});

test("un abonnement absent de Firestore est signalé", () => {
  const divergences = diffSubscriptionRecord(stripeSubscription, undefined);
  assert.equal(divergences.length, 1);
  assert.equal(divergences[0]?.field, "document");
  assert.equal(divergences[0]?.subscriptionId, "sub_123");
});

test("un abonnement annulé chez Stripe mais actif dans l'app est détecté", () => {
  // Le cas que le recoupement existe pour attraper : webhook perdu, accès
  // payant maintenu indéfiniment.
  const divergences = diffSubscriptionRecord(
    { ...stripeSubscription, status: "canceled" },
    storedSubscription,
  );
  assert.equal(divergences.length, 1);
  assert.equal(divergences[0]?.field, "status");
  assert.equal(divergences[0]?.stripe, "canceled");
  assert.equal(divergences[0]?.firestore, "active");
});

test("une résiliation en fin de période non répercutée est détectée", () => {
  const divergences = diffSubscriptionRecord(
    { ...stripeSubscription, cancel_at_period_end: true },
    storedSubscription,
  );
  assert.equal(divergences.length, 1);
  assert.equal(divergences[0]?.field, "cancel_at_period_end");
});

test("les secondes Stripe et les millisecondes Firestore sont comparables", () => {
  assert.deepEqual(
    diffSubscriptionRecord(stripeSubscription, {
      ...storedSubscription,
      // 400 ms de décalage : même seconde, donc pas une divergence.
      current_period_end: 1_800_000_000_400,
    }),
    [],
  );

  const divergences = diffSubscriptionRecord(stripeSubscription, {
    ...storedSubscription,
    current_period_end: 1_700_000_000_000,
  });
  assert.equal(divergences[0]?.field, "current_period_end");
});

test("un changement de tarif non répercuté est détecté", () => {
  const divergences = diffSubscriptionRecord(stripeSubscription, {
    ...storedSubscription,
    stripe_price_id: "price_pro",
  });
  assert.equal(divergences.length, 1);
  assert.equal(divergences[0]?.field, "stripe_price_id");
});

test("plusieurs écarts sur un même abonnement sont tous remontés", () => {
  const divergences = diffSubscriptionRecord(
    { ...stripeSubscription, status: "past_due", cancel_at_period_end: true },
    storedSubscription,
  );
  assert.deepEqual(
    divergences.map((item) => item.field).sort(),
    ["cancel_at_period_end", "status"],
  );
});

test("le résumé compte les abonnements, pas les écarts", () => {
  const summary = summarize(
    [
      [],
      [
        { subscriptionId: "sub_a", field: "status", stripe: "x", firestore: "y" },
        { subscriptionId: "sub_a", field: "price", stripe: "x", firestore: "y" },
      ],
      [{ subscriptionId: "sub_b", field: "status", stripe: "x", firestore: "y" }],
    ],
    false,
  );

  assert.equal(summary.scanned, 3);
  assert.equal(summary.diverging, 2);
  assert.equal(summary.divergences.length, 3);
  assert.equal(summary.truncated, false);
});

test("un balayage tronqué est signalé comme tel", () => {
  assert.equal(summarize([], true).truncated, true);
});
