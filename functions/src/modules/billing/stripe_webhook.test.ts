import assert from "node:assert/strict";
import test from "node:test";

import {
  isDeletedAccountStatus,
  normalizedInvoiceStatus,
  shouldApplyStripeEvent,
} from "./stripe_webhook";

test("Stripe ignore un événement plus ancien que l'état déjà traité", () => {
  assert.equal(shouldApplyStripeEvent(2_000, 1_999), false);
  assert.equal(shouldApplyStripeEvent(2_000, 2_000), true);
  assert.equal(shouldApplyStripeEvent(2_000, 2_001), true);
});

test("Stripe accepte un événement sans timestamp uniquement en repli", () => {
  assert.equal(shouldApplyStripeEvent(5_000, 0), true);
});

test("invoice.payment_failed est normalisé en impayé", () => {
  assert.equal(
    normalizedInvoiceStatus("invoice.payment_failed", { status: "open" }),
    "payment_failed",
  );
});

test("les événements payés sont normalisés en paid", () => {
  assert.equal(
    normalizedInvoiceStatus("invoice.payment_succeeded", { status: "open" }),
    "paid",
  );
  assert.equal(
    normalizedInvoiceStatus("invoice.paid", { status: "open" }),
    "paid",
  );
});

test("les actions requises et créances irrécouvrables sont distinguées", () => {
  assert.equal(
    normalizedInvoiceStatus("invoice.payment_action_required", { status: "open" }),
    "action_required",
  );
  assert.equal(
    normalizedInvoiceStatus("invoice.marked_uncollectible", { status: "open" }),
    "uncollectible",
  );
});

test("un webhook tardif ne réhydrate pas un compte supprimé", () => {
  assert.equal(isDeletedAccountStatus("deletion_processing"), true);
  assert.equal(isDeletedAccountStatus("deleted"), true);
  assert.equal(isDeletedAccountStatus("active"), false);
});
