"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const callables_1 = require("./callables");
const stripe_webhook_1 = require("./stripe_webhook");
// ── Idempotence sortante : ce que nous envoyons à Stripe ────────────────
(0, node_test_1.default)("la même requête produit toujours la même clé", () => {
    const parts = ["checkout", "user_1", "ilipro", 42];
    strict_1.default.equal((0, callables_1.idempotencyKey)(parts), (0, callables_1.idempotencyKey)([...parts]));
});
(0, node_test_1.default)("un seul élément différent change la clé", () => {
    const base = (0, callables_1.idempotencyKey)(["checkout", "user_1", "ilipro", 42]);
    strict_1.default.notEqual(base, (0, callables_1.idempotencyKey)(["checkout", "user_2", "ilipro", 42]));
    strict_1.default.notEqual(base, (0, callables_1.idempotencyKey)(["checkout", "user_1", "ilipresto_plus", 42]));
    strict_1.default.notEqual(base, (0, callables_1.idempotencyKey)(["checkout", "user_1", "ilipro", 43]));
});
(0, node_test_1.default)("la clé reste dans les limites acceptées par Stripe", () => {
    const key = (0, callables_1.idempotencyKey)(["checkout", "user_1", "ilipro", 42]);
    strict_1.default.ok(key.length <= 255, `clé trop longue: ${key.length}`);
    strict_1.default.match(key, /^ilipresto_[0-9a-f]{48}$/);
});
(0, node_test_1.default)("la clé ne laisse pas fuiter les valeurs d'origine", () => {
    // Un identifiant utilisateur ne doit pas être lisible dans la clé, qui
    // circule en clair dans les en-têtes et les journaux Stripe.
    const key = (0, callables_1.idempotencyKey)(["checkout", "user_secret_42", "ilipro"]);
    strict_1.default.equal(key.includes("user_secret_42"), false);
});
(0, node_test_1.default)("deux tentatives dans la même fenêtre partagent la clé", () => {
    // Fenêtre fixe et non glissante : les bornes tombent sur les multiples de
    // dix minutes depuis l'époque, d'où le point de départ aligné.
    const windowMs = 10 * 60 * 1000;
    const windowStart = Math.floor(1_000_000_000_000 / windowMs) * windowMs;
    strict_1.default.equal((0, callables_1.checkoutIdempotencyBucket)(windowStart), (0, callables_1.checkoutIdempotencyBucket)(windowStart + windowMs - 1));
    strict_1.default.notEqual((0, callables_1.checkoutIdempotencyBucket)(windowStart), (0, callables_1.checkoutIdempotencyBucket)(windowStart + windowMs));
});
(0, node_test_1.default)("deux tentatives séparées par une borne ne partagent pas la clé", () => {
    // Conséquence assumée de la fenêtre fixe : deux clics à une minute
    // d'intervalle de part et d'autre d'une borne créent deux sessions
    // Checkout. Sans conséquence — une session non payée expire seule.
    const windowMs = 10 * 60 * 1000;
    const justBeforeBoundary = Math.floor(1_000_000_000_000 / windowMs) * windowMs
        + windowMs - 30_000;
    strict_1.default.notEqual((0, callables_1.checkoutIdempotencyBucket)(justBeforeBoundary), (0, callables_1.checkoutIdempotencyBucket)(justBeforeBoundary + 60_000));
});
// ── Idempotence entrante : ce que Stripe nous rejoue ────────────────────
(0, node_test_1.default)("un événement jamais vu est traité", () => {
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)(undefined, 1_000), "process");
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)({}, 1_000), "process");
});
(0, node_test_1.default)("un événement déjà traité est un doublon", () => {
    // Stripe rejoue jusqu'au 2xx : le second passage ne doit rien réécrire.
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)({ status: "processed" }, 1_000), "duplicate");
});
(0, node_test_1.default)("un événement en cours de traitement bloque un traitement concurrent", () => {
    const now = 1_000_000;
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)({ status: "processing", processing_started_at_ms: now - 1_000 }, now, 60_000), "busy");
});
(0, node_test_1.default)("un bail expiré est repris au lieu de bloquer à vie", () => {
    // Cas d'une exécution tuée avant d'avoir libéré son bail : sans expiration,
    // l'événement resterait coincé en « processing » pour toujours.
    const now = 1_000_000;
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)({ status: "processing", processing_started_at_ms: now - 120_000 }, now, 60_000), "process");
});
(0, node_test_1.default)("un bail sans horodatage n'immobilise pas l'événement", () => {
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)({ status: "processing" }, 1_000, 60_000), "process");
});
(0, node_test_1.default)("un événement en échec est réessayé", () => {
    strict_1.default.equal((0, stripe_webhook_1.evaluateEventLease)({ status: "failed" }, 1_000), "process");
});
(0, node_test_1.default)("un événement plus ancien que l'état enregistré est ignoré", () => {
    // Stripe ne garantit pas l'ordre : `customer.subscription.updated` peut
    // arriver après le `deleted` qui le suit chronologiquement.
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(2_000, 1_999), false);
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(2_000, 2_000), true);
});
//# sourceMappingURL=idempotency.test.js.map