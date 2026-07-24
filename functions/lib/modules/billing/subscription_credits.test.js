"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const subscription_credits_1 = require("./subscription_credits");
(0, node_test_1.default)("normalise les plans utilisés par les crédits", () => {
    strict_1.default.equal((0, subscription_credits_1.normalizeSubscriptionCreditPlan)("free"), "free");
    strict_1.default.equal((0, subscription_credits_1.normalizeSubscriptionCreditPlan)("ilipresto+"), "ilipresto_plus");
    strict_1.default.equal((0, subscription_credits_1.normalizeSubscriptionCreditPlan)("ilipresto-plus"), "ilipresto_plus");
    strict_1.default.equal((0, subscription_credits_1.normalizeSubscriptionCreditPlan)("ilipro"), "ilipro");
    strict_1.default.equal((0, subscription_credits_1.normalizeSubscriptionCreditPlan)("inconnu"), "free");
});
(0, node_test_1.default)("applique les cinq limites du plan Gratuit", () => {
    strict_1.default.deepEqual((0, subscription_credits_1.subscriptionCreditLimitsForPlan)("free", false), {
        journeys: 2,
        pdf: 0,
        voiceAi: 1,
        textAi: 2,
        activeOffers: 3,
    });
});
(0, node_test_1.default)("applique les limites ilipresto+ et ilipro", () => {
    const plus = (0, subscription_credits_1.subscriptionCreditLimitsForPlan)("ilipresto_plus", false);
    const pro = (0, subscription_credits_1.subscriptionCreditLimitsForPlan)("ilipro", false);
    strict_1.default.equal(plus.journeys, 5);
    strict_1.default.equal(plus.pdf, 5);
    strict_1.default.equal(plus.voiceAi, 5);
    strict_1.default.equal(plus.textAi, subscription_credits_1.UNLIMITED_SUBSCRIPTION_CREDIT);
    strict_1.default.equal(pro.journeys, 10);
    strict_1.default.equal(pro.pdf, 10);
    strict_1.default.equal(pro.voiceAi, subscription_credits_1.UNLIMITED_SUBSCRIPTION_CREDIT);
    strict_1.default.equal(pro.activeOffers, 30);
});
(0, node_test_1.default)("le mode gratuit complet rend tous les crédits illimités", () => {
    for (const plan of ["free", "ilipresto_plus", "ilipro"]) {
        const limits = (0, subscription_credits_1.subscriptionCreditLimitsForPlan)(plan, true);
        for (const limit of Object.values(limits)) {
            strict_1.default.equal(limit, subscription_credits_1.UNLIMITED_SUBSCRIPTION_CREDIT);
        }
    }
});
(0, node_test_1.default)("le mois de consommation utilise UTC", () => {
    strict_1.default.equal((0, subscription_credits_1.subscriptionCreditPeriod)(new Date("2026-07-31T23:59:59Z")), "2026-07");
    strict_1.default.equal((0, subscription_credits_1.subscriptionCreditPeriod)(new Date("2026-08-01T00:00:00Z")), "2026-08");
});
(0, node_test_1.default)("compte uniquement les annonces réellement actives", () => {
    strict_1.default.equal((0, subscription_credits_1.isSubscriptionCreditActiveListing)({ status: "active" }), true);
    strict_1.default.equal((0, subscription_credits_1.isSubscriptionCreditActiveListing)({ isPublished: true }), true);
    strict_1.default.equal((0, subscription_credits_1.isSubscriptionCreditActiveListing)({ visibility: { isPublic: true } }), true);
    strict_1.default.equal((0, subscription_credits_1.isSubscriptionCreditActiveListing)({ status: "archived", isPublished: true }), false);
    strict_1.default.equal((0, subscription_credits_1.isSubscriptionCreditActiveListing)({ status: "active", deletedAt: "2026-01-01" }), false);
});
//# sourceMappingURL=subscription_credits.test.js.map