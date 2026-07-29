"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const logger_1 = require("./logger");
(0, node_test_1.default)("sanitizeLogContext strips sensitive AI and personal fields recursively", () => {
    const sanitized = (0, logger_1.sanitizeLogContext)({
        requestId: "req-1",
        model: "gpt-test",
        email: "person@example.test",
        nested: {
            prompt: "private prompt",
            audioBase64: "AAAA",
            durationMs: 42,
        },
    });
    strict_1.default.deepEqual(sanitized, {
        requestId: "req-1",
        model: "gpt-test",
        nested: { durationMs: 42 },
    });
});
(0, node_test_1.default)("sanitizeLogContext bounds oversized strings and arrays", () => {
    const sanitized = (0, logger_1.sanitizeLogContext)({
        safe: "x".repeat(700),
        values: Array.from({ length: 80 }, (_, index) => index),
    });
    strict_1.default.match(String(sanitized.safe), /\[TRUNCATED\]$/);
    strict_1.default.equal(sanitized.values.length, 50);
});
//# sourceMappingURL=logger.test.js.map