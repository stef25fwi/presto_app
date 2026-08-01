"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const refunds_1 = require("./refunds");
(0, node_test_1.default)("refund.failed prime sur le statut porté par l'objet", () => {
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("refund.failed", { status: "succeeded" }), "failed");
});
(0, node_test_1.default)("charge.refunded sans statut vaut remboursement acquis", () => {
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("charge.refunded", {}), "succeeded");
});
(0, node_test_1.default)("un remboursement sans statut connu reste en attente", () => {
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("refund.created", {}), "pending");
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("refund.updated", { status: "requires_action" }), "pending");
});
(0, node_test_1.default)("les statuts explicites sont repris tels quels", () => {
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("refund.updated", { status: "succeeded" }), "succeeded");
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("refund.updated", { status: "canceled" }), "canceled");
    strict_1.default.equal((0, refunds_1.normalizedRefundStatus)("refund.updated", { status: "cancelled" }), "canceled");
});
(0, node_test_1.default)("un litige gagné ou perdu est reconnu par son statut", () => {
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.closed", { status: "won" }), "won");
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.closed", { status: "lost" }), "lost");
});
(0, node_test_1.default)("les alertes réseau ne sont pas des litiges formels", () => {
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.created", { status: "warning_needs_response" }), "warning");
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.updated", { status: "warning_under_review" }), "warning");
});
(0, node_test_1.default)("le mouvement de fonds tranche quand le statut ne dit rien", () => {
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.funds_withdrawn", {}), "lost");
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.funds_reinstated", {}), "won");
});
(0, node_test_1.default)("un litige ouvert reste ouvert", () => {
    strict_1.default.equal((0, refunds_1.disputeOutcome)("charge.dispute.created", { status: "needs_response" }), "open");
});
(0, node_test_1.default)("le montant remboursé est cumulatif, jamais additionné deux fois", () => {
    const charge = { amount: 999, amount_refunded: 400 };
    strict_1.default.equal((0, refunds_1.refundedAmountFromCharge)(charge), 400);
    strict_1.default.equal((0, refunds_1.isFullRefund)(charge), false);
    const fullyRefunded = { amount: 999, amount_refunded: 999 };
    strict_1.default.equal((0, refunds_1.isFullRefund)(fullyRefunded), true);
});
(0, node_test_1.default)("une charge sans montant n'est jamais un remboursement total", () => {
    strict_1.default.equal((0, refunds_1.isFullRefund)({ amount: 0, amount_refunded: 0 }), false);
});
(0, node_test_1.default)("un montant remboursé négatif est ramené à zéro", () => {
    strict_1.default.equal((0, refunds_1.refundedAmountFromCharge)({ amount_refunded: -10 }), 0);
});
(0, node_test_1.default)("les incidents à revoir sont ceux qui engagent de l'argent", () => {
    strict_1.default.equal((0, refunds_1.requiresBillingReview)("refund", "succeeded"), true);
    strict_1.default.equal((0, refunds_1.requiresBillingReview)("refund", "pending"), false);
    strict_1.default.equal((0, refunds_1.requiresBillingReview)("dispute", "lost"), true);
    strict_1.default.equal((0, refunds_1.requiresBillingReview)("dispute", "open"), true);
    strict_1.default.equal((0, refunds_1.requiresBillingReview)("dispute", "warning"), true);
    strict_1.default.equal((0, refunds_1.requiresBillingReview)("dispute", "won"), false);
});
//# sourceMappingURL=refunds.test.js.map