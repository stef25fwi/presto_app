"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const recaptcha_1 = require("./recaptcha");
function buildResult(overrides = {}) {
    return {
        allowed: true,
        score: 0.9,
        reasons: [],
        action: "listing_submit",
        tokenValid: true,
        actionMatches: true,
        meetsScoreThreshold: true,
        assessed: true,
        ...overrides,
    };
}
(0, node_test_1.default)("listing submission is rejected when token is invalid", () => {
    strict_1.default.equal((0, recaptcha_1.shouldRejectListingSubmissionForRecaptcha)(buildResult({
        allowed: false,
        tokenValid: false,
        actionMatches: false,
        meetsScoreThreshold: false,
    })), true);
});
(0, node_test_1.default)("listing submission is rejected when action does not match", () => {
    strict_1.default.equal((0, recaptcha_1.shouldRejectListingSubmissionForRecaptcha)(buildResult({
        allowed: false,
        action: "other_action",
        actionMatches: false,
    })), true);
});
(0, node_test_1.default)("listing submission is not rejected solely for low score", () => {
    strict_1.default.equal((0, recaptcha_1.shouldRejectListingSubmissionForRecaptcha)(buildResult({
        allowed: false,
        score: 0.2,
        meetsScoreThreshold: false,
    })), false);
});
(0, node_test_1.default)("listing submission is not rejected when the assessment is unavailable", () => {
    // Server misconfiguration / assessment error: no verdict was obtained, so
    // publication must fail open instead of blocking every user.
    strict_1.default.equal((0, recaptcha_1.shouldRejectListingSubmissionForRecaptcha)(buildResult({
        allowed: false,
        reasons: ["MISSING_RECAPTCHA_CONFIGURATION"],
        tokenValid: false,
        actionMatches: false,
        meetsScoreThreshold: false,
        assessed: false,
    })), false);
});
//# sourceMappingURL=recaptcha.test.js.map