"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getOpenAiClient = getOpenAiClient;
exports.classifyOpenAiError = classifyOpenAiError;
exports.logOpenAiSuccess = logOpenAiSuccess;
exports.logOpenAiFailure = logOpenAiFailure;
const openai_1 = __importDefault(require("openai"));
const env_1 = require("../../config/env");
const logger_1 = require("../../core/logger");
const DEFAULT_TIMEOUT_MS = 25_000;
const DEFAULT_MAX_RETRIES = 1;
let singletonClient = null;
let singletonApiKey = "";
function optionalString(value) {
    if (typeof value !== "string")
        return null;
    const normalized = value.trim();
    return normalized || null;
}
function optionalNumber(value) {
    const parsed = typeof value === "number" ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}
function getOpenAiClient() {
    const apiKey = env_1.OPENAI_API_KEY.value().trim();
    if (!apiKey) {
        throw new Error("OPENAI_API_KEY_NOT_CONFIGURED");
    }
    if (singletonClient && singletonApiKey === apiKey) {
        return singletonClient;
    }
    singletonApiKey = apiKey;
    singletonClient = new openai_1.default({
        apiKey,
        timeout: DEFAULT_TIMEOUT_MS,
        maxRetries: DEFAULT_MAX_RETRIES,
    });
    return singletonClient;
}
function classifyOpenAiError(error) {
    const value = error;
    const status = optionalNumber(value?.status);
    const code = optionalString(value?.code);
    const type = optionalString(value?.type);
    const requestId = optionalString(value?.request_id) ||
        optionalString(value?._request_id) ||
        optionalString(value?.headers?.["x-request-id"]);
    const name = optionalString(value?.name) || "Error";
    const message = optionalString(value?.message) || String(error);
    const normalizedMessage = message.toLowerCase();
    const normalizedCode = (code || "").toLowerCase();
    const timeout = name.includes("Timeout") ||
        normalizedCode.includes("timeout") ||
        normalizedMessage.includes("timeout") ||
        normalizedMessage.includes("timed out");
    const quotaExhausted = status === 429 &&
        (normalizedCode.includes("insufficient_quota") ||
            normalizedMessage.includes("insufficient quota") ||
            normalizedMessage.includes("billing") ||
            normalizedMessage.includes("credit"));
    const retryable = timeout ||
        status === 408 ||
        status === 409 ||
        (status === 429 && !quotaExhausted) ||
        (status != null && status >= 500) ||
        name.includes("APIConnectionError");
    return {
        status,
        code,
        type,
        requestId,
        name,
        message,
        retryable,
        timeout,
        quotaExhausted,
    };
}
function logOpenAiSuccess(context, response) {
    const usage = response.usage || null;
    logger_1.logger.info("openai.operation.success", {
        operation: context.operation,
        requestId: context.requestId,
        openAiRequestId: response._request_id || null,
        model: context.model,
        promptVersion: context.promptVersion || null,
        schemaVersion: context.schemaVersion || null,
        durationMs: Date.now() - context.startedAtMs,
        cacheHit: context.cacheHit === true,
        inputTokens: usage?.prompt_tokens ?? null,
        cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens ?? null,
        outputTokens: usage?.completion_tokens ?? null,
        totalTokens: usage?.total_tokens ?? null,
    });
}
function logOpenAiFailure(context, error) {
    const info = classifyOpenAiError(error);
    logger_1.logger.error("openai.operation.failure", {
        operation: context.operation,
        requestId: context.requestId,
        openAiRequestId: info.requestId,
        model: context.model,
        promptVersion: context.promptVersion || null,
        schemaVersion: context.schemaVersion || null,
        durationMs: Date.now() - context.startedAtMs,
        status: info.status,
        code: info.code,
        type: info.type,
        errorName: info.name,
        retryable: info.retryable,
        timeout: info.timeout,
        quotaExhausted: info.quotaExhausted,
    });
    return info;
}
//# sourceMappingURL=openai_runtime.js.map