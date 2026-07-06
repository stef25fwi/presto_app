"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const moderation_1 = require("./moderation");
(0, node_test_1.default)("hidden_until_validated is the only synchronous messaging moderation mode", () => {
    strict_1.default.equal((0, moderation_1.shouldModerateSynchronouslyBeforeSend)("hidden_until_validated"), true);
    strict_1.default.equal((0, moderation_1.shouldModerateSynchronouslyBeforeSend)("visible_then_retract"), false);
    strict_1.default.equal((0, moderation_1.shouldModerateSynchronouslyBeforeSend)("hybrid"), false);
});
(0, node_test_1.default)("visible_then_retract only hides blocked content after async moderation", () => {
    strict_1.default.deepEqual((0, moderation_1.resolveMessagingModerationRecord)({
        mode: "visible_then_retract",
        moderationDecision: "blocked",
    }), { status: "rejected", visibility: "hidden" });
    strict_1.default.deepEqual((0, moderation_1.resolveMessagingModerationRecord)({
        mode: "visible_then_retract",
        moderationDecision: "manual_review",
    }), { status: "approved", visibility: "visible" });
});
(0, node_test_1.default)("hybrid hides flagged or manual review messaging content", () => {
    strict_1.default.deepEqual((0, moderation_1.resolveMessagingModerationRecord)({
        mode: "hybrid",
        moderationDecision: "auto_flagged",
    }), { status: "manual_review", visibility: "hidden" });
    strict_1.default.deepEqual((0, moderation_1.resolveMessagingModerationRecord)({
        mode: "hybrid",
        moderationDecision: "approved",
    }), { status: "approved", visibility: "visible" });
});
(0, node_test_1.default)("pending moderation records stay visible until async resolution", () => {
    strict_1.default.deepEqual((0, moderation_1.buildPendingMessagingModeration)("hybrid"), {
        mode: "hybrid",
        status: "pending",
        visibility: "visible",
        moderationDecision: "approved",
        moderationReason: "pending_async_review",
        userMessage: "",
        autoFlags: [],
        riskScore: 0,
        textScanStatus: "pending",
        imageScanStatus: "pending",
    });
});
//# sourceMappingURL=moderation.test.js.map