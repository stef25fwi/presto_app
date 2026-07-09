"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const https_1 = require("firebase-functions/v2/https");
const callables_1 = require("./callables");
(0, node_test_1.default)("normalizePayablePlan accepts every known ilipresto+ key variant", () => {
    strict_1.default.equal((0, callables_1.normalizePayablePlan)("ilipresto_plus"), "ilipresto_plus");
    strict_1.default.equal((0, callables_1.normalizePayablePlan)("iliprestoplus"), "ilipresto_plus");
    strict_1.default.equal((0, callables_1.normalizePayablePlan)("ilipresto+"), "ilipresto_plus");
});
(0, node_test_1.default)("normalizePayablePlan accepts ilipro", () => {
    strict_1.default.equal((0, callables_1.normalizePayablePlan)("ilipro"), "ilipro");
});
(0, node_test_1.default)("normalizePayablePlan rejects the free plan and unknown values", () => {
    strict_1.default.throws(() => (0, callables_1.normalizePayablePlan)("free"), https_1.HttpsError);
    strict_1.default.throws(() => (0, callables_1.normalizePayablePlan)("unknown"), https_1.HttpsError);
    strict_1.default.throws(() => (0, callables_1.normalizePayablePlan)(undefined), https_1.HttpsError);
});
(0, node_test_1.default)("resolvePriceIdForPlan fails clearly while Stripe price ids are not configured yet", () => {
    // STRIPE_PRICE_ILIPRESTO_PLUS / STRIPE_PRICE_ILIPRO are unset in this test
    // environment (and in production until the Stripe products are created),
    // so this must surface a clear precondition error rather than silently
    // creating a checkout session with an empty price id.
    strict_1.default.throws(() => (0, callables_1.resolvePriceIdForPlan)("ilipresto_plus"), https_1.HttpsError);
    strict_1.default.throws(() => (0, callables_1.resolvePriceIdForPlan)("ilipro"), https_1.HttpsError);
});
//# sourceMappingURL=callables.test.js.map