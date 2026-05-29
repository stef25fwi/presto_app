"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const reviews_1 = require("./reviews");
(0, node_test_1.default)("calculateReviewAverage stores the verified review mean with three decimals", () => {
    strict_1.default.equal((0, reviews_1.calculateReviewAverage)(5, 4, 5), 4.667);
    strict_1.default.equal((0, reviews_1.calculateReviewAverage)(1, 1, 1), 1);
    strict_1.default.equal((0, reviews_1.calculateReviewAverage)(5, 5, 5), 5);
});
(0, node_test_1.default)("analyzeReviewText publishes clean optional comments", () => {
    const result = (0, reviews_1.analyzeReviewText)("Très bonne communication, mission terminée proprement.");
    strict_1.default.equal(result.status, "published");
    strict_1.default.equal(result.comment, "Très bonne communication, mission terminée proprement.");
    strict_1.default.deepEqual(result.flags, {
        containsPersonalData: false,
        containsInsult: false,
        containsThreat: false,
        containsSuspiciousContent: false,
    });
});
(0, node_test_1.default)("analyzeReviewText sends personal data to moderation", () => {
    const result = (0, reviews_1.analyzeReviewText)("Contact possible au 06 12 34 56 78 pour confirmer.");
    strict_1.default.equal(result.status, "pending_moderation");
    strict_1.default.equal(result.flags.containsPersonalData, true);
});
(0, node_test_1.default)("ratings paid showcase remains disabled at launch", () => {
    strict_1.default.equal(reviews_1.ratingsPaidShowcaseEnabled, false);
});
//# sourceMappingURL=reviews.test.js.map