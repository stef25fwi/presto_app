"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const stripe_webhook_1 = require("./stripe_webhook");
(0, node_test_1.default)("Stripe ignore un événement plus ancien que l'état déjà traité", () => {
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(2_000, 1_999), false);
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(2_000, 2_000), true);
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(2_000, 2_001), true);
});
(0, node_test_1.default)("Stripe accepte un événement sans timestamp uniquement en repli", () => {
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(5_000, 0), true);
});
(0, node_test_1.default)("invoice.payment_failed est normalisé en impayé", () => {
    strict_1.default.equal((0, stripe_webhook_1.normalizedInvoiceStatus)("invoice.payment_failed", { status: "open" }), "payment_failed");
});
(0, node_test_1.default)("les événements payés sont normalisés en paid", () => {
    strict_1.default.equal((0, stripe_webhook_1.normalizedInvoiceStatus)("invoice.payment_succeeded", { status: "open" }), "paid");
    strict_1.default.equal((0, stripe_webhook_1.normalizedInvoiceStatus)("invoice.paid", { status: "open" }), "paid");
});
(0, node_test_1.default)("les actions requises et créances irrécouvrables sont distinguées", () => {
    strict_1.default.equal((0, stripe_webhook_1.normalizedInvoiceStatus)("invoice.payment_action_required", { status: "open" }), "action_required");
    strict_1.default.equal((0, stripe_webhook_1.normalizedInvoiceStatus)("invoice.marked_uncollectible", { status: "open" }), "uncollectible");
});
(0, node_test_1.default)("un webhook tardif ne réhydrate pas un compte supprimé", () => {
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("deletion_processing"), true);
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("deleted"), true);
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("active"), false);
});
//# sourceMappingURL=stripe_webhook.test.js.map