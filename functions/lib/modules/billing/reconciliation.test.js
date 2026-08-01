"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const reconciliation_1 = require("./reconciliation");
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
(0, node_test_1.default)("un abonnement identique ne produit aucune divergence", () => {
    strict_1.default.deepEqual((0, reconciliation_1.diffSubscriptionRecord)(stripeSubscription, storedSubscription), []);
});
(0, node_test_1.default)("un abonnement absent de Firestore est signalé", () => {
    const divergences = (0, reconciliation_1.diffSubscriptionRecord)(stripeSubscription, undefined);
    strict_1.default.equal(divergences.length, 1);
    strict_1.default.equal(divergences[0]?.field, "document");
    strict_1.default.equal(divergences[0]?.subscriptionId, "sub_123");
});
(0, node_test_1.default)("un abonnement annulé chez Stripe mais actif dans l'app est détecté", () => {
    // Le cas que le recoupement existe pour attraper : webhook perdu, accès
    // payant maintenu indéfiniment.
    const divergences = (0, reconciliation_1.diffSubscriptionRecord)({ ...stripeSubscription, status: "canceled" }, storedSubscription);
    strict_1.default.equal(divergences.length, 1);
    strict_1.default.equal(divergences[0]?.field, "status");
    strict_1.default.equal(divergences[0]?.stripe, "canceled");
    strict_1.default.equal(divergences[0]?.firestore, "active");
});
(0, node_test_1.default)("une résiliation en fin de période non répercutée est détectée", () => {
    const divergences = (0, reconciliation_1.diffSubscriptionRecord)({ ...stripeSubscription, cancel_at_period_end: true }, storedSubscription);
    strict_1.default.equal(divergences.length, 1);
    strict_1.default.equal(divergences[0]?.field, "cancel_at_period_end");
});
(0, node_test_1.default)("les secondes Stripe et les millisecondes Firestore sont comparables", () => {
    strict_1.default.deepEqual((0, reconciliation_1.diffSubscriptionRecord)(stripeSubscription, {
        ...storedSubscription,
        // 400 ms de décalage : même seconde, donc pas une divergence.
        current_period_end: 1_800_000_000_400,
    }), []);
    const divergences = (0, reconciliation_1.diffSubscriptionRecord)(stripeSubscription, {
        ...storedSubscription,
        current_period_end: 1_700_000_000_000,
    });
    strict_1.default.equal(divergences[0]?.field, "current_period_end");
});
(0, node_test_1.default)("un changement de tarif non répercuté est détecté", () => {
    const divergences = (0, reconciliation_1.diffSubscriptionRecord)(stripeSubscription, {
        ...storedSubscription,
        stripe_price_id: "price_pro",
    });
    strict_1.default.equal(divergences.length, 1);
    strict_1.default.equal(divergences[0]?.field, "stripe_price_id");
});
(0, node_test_1.default)("plusieurs écarts sur un même abonnement sont tous remontés", () => {
    const divergences = (0, reconciliation_1.diffSubscriptionRecord)({ ...stripeSubscription, status: "past_due", cancel_at_period_end: true }, storedSubscription);
    strict_1.default.deepEqual(divergences.map((item) => item.field).sort(), ["cancel_at_period_end", "status"]);
});
(0, node_test_1.default)("le résumé compte les abonnements, pas les écarts", () => {
    const summary = (0, reconciliation_1.summarize)([
        [],
        [
            { subscriptionId: "sub_a", field: "status", stripe: "x", firestore: "y" },
            { subscriptionId: "sub_a", field: "price", stripe: "x", firestore: "y" },
        ],
        [{ subscriptionId: "sub_b", field: "status", stripe: "x", firestore: "y" }],
    ], false);
    strict_1.default.equal(summary.scanned, 3);
    strict_1.default.equal(summary.diverging, 2);
    strict_1.default.equal(summary.divergences.length, 3);
    strict_1.default.equal(summary.truncated, false);
});
(0, node_test_1.default)("un balayage tronqué est signalé comme tel", () => {
    strict_1.default.equal((0, reconciliation_1.summarize)([], true).truncated, true);
});
//# sourceMappingURL=reconciliation.test.js.map