"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const openai_runtime_1 = require("./openai_runtime");
(0, node_test_1.default)("classifyOpenAiError marks transient rate limits as retryable", () => {
    const result = (0, openai_runtime_1.classifyOpenAiError)({
        status: 429,
        code: "rate_limit_exceeded",
        message: "Too many requests",
        request_id: "req_rate",
    });
    strict_1.default.equal(result.status, 429);
    strict_1.default.equal(result.requestId, "req_rate");
    strict_1.default.equal(result.retryable, true);
    strict_1.default.equal(result.quotaExhausted, false);
});
(0, node_test_1.default)("classifyOpenAiError separates exhausted quota from transient 429", () => {
    const result = (0, openai_runtime_1.classifyOpenAiError)({
        status: 429,
        code: "insufficient_quota",
        message: "Insufficient quota for this project",
    });
    strict_1.default.equal(result.retryable, false);
    strict_1.default.equal(result.quotaExhausted, true);
});
(0, node_test_1.default)("classifyOpenAiError recognizes connection timeouts", () => {
    const result = (0, openai_runtime_1.classifyOpenAiError)({
        name: "APIConnectionTimeoutError",
        code: "ETIMEDOUT",
        message: "Request timed out",
    });
    strict_1.default.equal(result.timeout, true);
    strict_1.default.equal(result.retryable, true);
});
(0, node_test_1.default)("classifyOpenAiError keeps invalid requests final", () => {
    const result = (0, openai_runtime_1.classifyOpenAiError)({
        status: 400,
        code: "invalid_request_error",
        message: "Invalid input",
    });
    strict_1.default.equal(result.timeout, false);
    strict_1.default.equal(result.retryable, false);
});
//# sourceMappingURL=openai_runtime.test.js.map