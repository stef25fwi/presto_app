import assert from "node:assert/strict";
import test from "node:test";

import {
  disputeOutcome,
  isFullRefund,
  normalizedRefundStatus,
  refundedAmountFromCharge,
  requiresBillingReview,
} from "./refunds";

test("refund.failed prime sur le statut porté par l'objet", () => {
  assert.equal(
    normalizedRefundStatus("refund.failed", { status: "succeeded" }),
    "failed",
  );
});

test("charge.refunded sans statut vaut remboursement acquis", () => {
  assert.equal(normalizedRefundStatus("charge.refunded", {}), "succeeded");
});

test("un remboursement sans statut connu reste en attente", () => {
  assert.equal(normalizedRefundStatus("refund.created", {}), "pending");
  assert.equal(
    normalizedRefundStatus("refund.updated", { status: "requires_action" }),
    "pending",
  );
});

test("les statuts explicites sont repris tels quels", () => {
  assert.equal(
    normalizedRefundStatus("refund.updated", { status: "succeeded" }),
    "succeeded",
  );
  assert.equal(
    normalizedRefundStatus("refund.updated", { status: "canceled" }),
    "canceled",
  );
  assert.equal(
    normalizedRefundStatus("refund.updated", { status: "cancelled" }),
    "canceled",
  );
});

test("un litige gagné ou perdu est reconnu par son statut", () => {
  assert.equal(disputeOutcome("charge.dispute.closed", { status: "won" }), "won");
  assert.equal(disputeOutcome("charge.dispute.closed", { status: "lost" }), "lost");
});

test("les alertes réseau ne sont pas des litiges formels", () => {
  assert.equal(
    disputeOutcome("charge.dispute.created", { status: "warning_needs_response" }),
    "warning",
  );
  assert.equal(
    disputeOutcome("charge.dispute.updated", { status: "warning_under_review" }),
    "warning",
  );
});

test("le mouvement de fonds tranche quand le statut ne dit rien", () => {
  assert.equal(disputeOutcome("charge.dispute.funds_withdrawn", {}), "lost");
  assert.equal(disputeOutcome("charge.dispute.funds_reinstated", {}), "won");
});

test("un litige ouvert reste ouvert", () => {
  assert.equal(
    disputeOutcome("charge.dispute.created", { status: "needs_response" }),
    "open",
  );
});

test("le montant remboursé est cumulatif, jamais additionné deux fois", () => {
  const charge = { amount: 999, amount_refunded: 400 };
  assert.equal(refundedAmountFromCharge(charge), 400);
  assert.equal(isFullRefund(charge), false);

  const fullyRefunded = { amount: 999, amount_refunded: 999 };
  assert.equal(isFullRefund(fullyRefunded), true);
});

test("une charge sans montant n'est jamais un remboursement total", () => {
  assert.equal(isFullRefund({ amount: 0, amount_refunded: 0 }), false);
});

test("un montant remboursé négatif est ramené à zéro", () => {
  assert.equal(refundedAmountFromCharge({ amount_refunded: -10 }), 0);
});

test("les incidents à revoir sont ceux qui engagent de l'argent", () => {
  assert.equal(requiresBillingReview("refund", "succeeded"), true);
  assert.equal(requiresBillingReview("refund", "pending"), false);
  assert.equal(requiresBillingReview("dispute", "lost"), true);
  assert.equal(requiresBillingReview("dispute", "open"), true);
  assert.equal(requiresBillingReview("dispute", "warning"), true);
  assert.equal(requiresBillingReview("dispute", "won"), false);
});
