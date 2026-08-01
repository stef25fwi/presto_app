"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_crypto_1 = require("node:crypto");
const node_test_1 = __importDefault(require("node:test"));
const stripe_webhook_1 = require("./stripe_webhook");
const SECRET = "whsec_test_secret";
function sign(body, timestampSeconds, secret = SECRET) {
    const signature = (0, node_crypto_1.createHmac)("sha256", secret)
        .update(`${timestampSeconds}.${body}`)
        .digest("hex");
    return `t=${timestampSeconds},v1=${signature}`;
}
function nowSeconds() {
    return Math.floor(Date.now() / 1000);
}
const payload = JSON.stringify({
    id: "evt_1",
    type: "checkout.session.completed",
    livemode: false,
    created: 1_700_000_000,
    data: { object: { id: "cs_1", subscription: "sub_1" } },
});
(0, node_test_1.default)("une charge utile correctement signée est acceptée", () => {
    const timestamp = nowSeconds();
    strict_1.default.doesNotThrow(() => {
        (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), sign(payload, timestamp), SECRET);
    });
});
(0, node_test_1.default)("un corps modifié après signature est rejeté", () => {
    const timestamp = nowSeconds();
    const header = sign(payload, timestamp);
    const tampered = payload.replace("cs_1", "cs_2");
    strict_1.default.throws(() => (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(tampered), header, SECRET), /Signature Stripe incorrecte/);
});
(0, node_test_1.default)("une signature d'un autre secret est rejetée", () => {
    // Cas concret : le secret du webhook de test recopié en production.
    const timestamp = nowSeconds();
    const header = sign(payload, timestamp, "whsec_autre_environnement");
    strict_1.default.throws(() => (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), header, SECRET), /Signature Stripe incorrecte/);
});
(0, node_test_1.default)("un rejeu hors de la fenêtre de tolérance est rejeté", () => {
    const old = nowSeconds() - 10 * 60;
    strict_1.default.throws(() => (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), sign(payload, old), SECRET), /Signature Stripe expirée/);
});
(0, node_test_1.default)("un horodatage futur hors tolérance est aussi rejeté", () => {
    const ahead = nowSeconds() + 10 * 60;
    strict_1.default.throws(() => (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), sign(payload, ahead), SECRET), /Signature Stripe expirée/);
});
(0, node_test_1.default)("un en-tête absent, vide ou malformé est rejeté", () => {
    for (const header of ["", "v1=abc", "t=123", "n'importe quoi"]) {
        strict_1.default.throws(() => (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), header, SECRET), /Signature Stripe absente ou invalide|Horodatage Stripe invalide/, `en-tête accepté à tort: ${header}`);
    }
});
(0, node_test_1.default)("un horodatage non numérique est rejeté", () => {
    strict_1.default.throws(() => (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), "t=abc,v1=def", SECRET), /Horodatage Stripe invalide/);
});
(0, node_test_1.default)("plusieurs signatures v1 sont acceptées si l'une est valide", () => {
    // Stripe en émet deux pendant une rotation de secret.
    const timestamp = nowSeconds();
    const valid = sign(payload, timestamp).split("v1=")[1];
    const header = `t=${timestamp},v1=${"0".repeat(64)},v1=${valid}`;
    strict_1.default.doesNotThrow(() => {
        (0, stripe_webhook_1.verifyStripeSignature)(Buffer.from(payload), header, SECRET);
    });
});
(0, node_test_1.default)("le dernier remboursement d'une charge est le plus récent", () => {
    const charge = {
        refunds: {
            data: [
                { id: "re_ancien", created: 100 },
                { id: "re_recent", created: 300 },
                { id: "re_median", created: 200 },
            ],
        },
    };
    strict_1.default.equal((0, stripe_webhook_1.latestRefundOfCharge)(charge).id, "re_recent");
});
(0, node_test_1.default)("une charge sans remboursement ne casse pas le traitement", () => {
    strict_1.default.deepEqual((0, stripe_webhook_1.latestRefundOfCharge)({}), {});
    strict_1.default.deepEqual((0, stripe_webhook_1.latestRefundOfCharge)({ refunds: { data: [] } }), {});
});
//# sourceMappingURL=stripe_signature.test.js.map