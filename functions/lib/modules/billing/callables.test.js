"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const callables_1 = require("./callables");
(0, node_test_1.default)("normalise les deux plans payants", () => {
    strict_1.default.equal((0, callables_1.normalizePlan)("ilipresto+"), "ilipresto_plus");
    strict_1.default.equal((0, callables_1.normalizePlan)("ilipresto_plus"), "ilipresto_plus");
    strict_1.default.equal((0, callables_1.normalizePlan)("ilipro"), "ilipro");
});
(0, node_test_1.default)("utilise une fenêtre idempotente de dix minutes", () => {
    strict_1.default.equal((0, callables_1.checkoutIdempotencyBucket)(0), 0);
    strict_1.default.equal((0, callables_1.checkoutIdempotencyBucket)(599_999), 0);
    strict_1.default.equal((0, callables_1.checkoutIdempotencyBucket)(600_000), 1);
});
(0, node_test_1.default)("réutilise une session Checkout encore suffisamment valide", () => {
    const now = 1_000_000;
    strict_1.default.equal((0, callables_1.isCheckoutIntentFresh)(now + 61_000, now), true);
    strict_1.default.equal((0, callables_1.isCheckoutIntentFresh)(now + 60_000, now), false);
    strict_1.default.equal((0, callables_1.isCheckoutIntentFresh)(now - 1, now), false);
});
(0, node_test_1.default)("bloque la création d'un second abonnement actif ou impayé", () => {
    for (const status of [
        "active",
        "trialing",
        "past_due",
        "unpaid",
        "incomplete",
        "paused",
    ]) {
        strict_1.default.equal((0, callables_1.isBlockingSubscriptionStatus)(status), true, status);
    }
    strict_1.default.equal((0, callables_1.isBlockingSubscriptionStatus)("pastDue"), true);
    strict_1.default.equal((0, callables_1.isBlockingSubscriptionStatus)("canceled"), false);
    strict_1.default.equal((0, callables_1.isBlockingSubscriptionStatus)("incomplete_expired"), false);
});
(0, node_test_1.default)("l'URL de succès conserve l'identifiant de session Stripe", () => {
    const previous = process.env.STRIPE_SUCCESS_URL;
    delete process.env.STRIPE_SUCCESS_URL;
    try {
        const url = (0, callables_1.checkoutSuccessUrl)();
        strict_1.default.match(url, /^https:\/\/ilipresto\.web\.app\/account\?/);
        strict_1.default.match(url, /section=subscriptions/);
        strict_1.default.match(url, /subscription=success/);
        strict_1.default.match(url, /session_id=\{CHECKOUT_SESSION_ID\}/);
    }
    finally {
        if (previous === undefined) {
            delete process.env.STRIPE_SUCCESS_URL;
        }
        else {
            process.env.STRIPE_SUCCESS_URL = previous;
        }
    }
});
//# sourceMappingURL=callables.test.js.map