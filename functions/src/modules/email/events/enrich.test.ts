import assert from "node:assert/strict";
import test from "node:test";
import { buildBillingInvoiceEnrichment, buildSubscriptionEnrichment } from "./enrich";

test("billing invoice enrichment adds currency, method and retry info", () => {
  const source = {
    amount_due: 39.99,
    currency: "EUR",
    payment_method_label: "Carte Visa **** 4242",
    next_retry_at: 1760000000000,
  };
  const payload = {};

  const extra = buildBillingInvoiceEnrichment(source, payload);
  assert.equal(extra.amount, 39.99);
  assert.equal(extra.currency, "EUR");
  assert.equal(extra.paymentMethod, "Carte Visa **** 4242");
  assert.equal(extra.nextRetryAt, 1760000000000);
  assert.equal(extra.retryUrl, "https://presto.app/facturation");
});

test("billing invoice enrichment respects existing payload values", () => {
  const source = {
    amount_due: 39.99,
    currency: "USD",
    payment_method_label: "Card",
    next_retry_at: 1760000000000,
  };
  const payload = {
    amount: 10,
    currency: "EUR",
    paymentMethod: "SEPA",
    nextRetryAt: 1,
    retryUrl: "https://x",
  };

  const extra = buildBillingInvoiceEnrichment(source, payload);
  assert.equal(extra.amount, undefined);
  assert.equal(extra.currency, undefined);
  assert.equal(extra.paymentMethod, undefined);
  assert.equal(extra.nextRetryAt, undefined);
  assert.equal(extra.retryUrl, undefined);
});

test("subscription enrichment defaults plan and manageUrl", () => {
  const source = {
    current_period_end: 1760000000000,
    payment_method: "SEPA",
  };
  const payload = {};

  const extra = buildSubscriptionEnrichment(source, payload);
  assert.equal(extra.planName, "PRESTO Premium");
  assert.equal(extra.currency, "EUR");
  assert.equal(extra.paymentMethod, "SEPA");
  assert.equal(extra.manageUrl, "https://presto.app/abonnement");
  assert.equal(typeof extra.renewalDate, "string");
});
