"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const webhook_1 = require("./webhook");
(0, node_test_1.default)("resolvePlanForPriceId defaults to free when no price id or unknown price id matches", () => {
    strict_1.default.equal((0, webhook_1.resolvePlanForPriceId)(undefined), "free");
    strict_1.default.equal((0, webhook_1.resolvePlanForPriceId)("price_unrelated"), "free");
});
(0, node_test_1.default)("resolveInternalStatus maps active and trialing to active access", () => {
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("active"), "active");
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("trialing"), "active");
});
(0, node_test_1.default)("resolveInternalStatus maps past_due and unpaid to past_due", () => {
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("past_due"), "past_due");
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("unpaid"), "past_due");
});
(0, node_test_1.default)("resolveInternalStatus maps canceled and incomplete_expired to canceled", () => {
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("canceled"), "canceled");
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("incomplete_expired"), "canceled");
});
(0, node_test_1.default)("resolveInternalStatus falls back to inactive for incomplete/paused", () => {
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("incomplete"), "inactive");
    strict_1.default.equal((0, webhook_1.resolveInternalStatus)("paused"), "inactive");
});
//# sourceMappingURL=webhook.test.js.map