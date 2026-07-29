"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveTtsConfig = resolveTtsConfig;
exports.buildTtsTextHash = buildTtsTextHash;
exports.generateTtsMp3 = generateTtsMp3;
const node_crypto_1 = __importDefault(require("node:crypto"));
const https_1 = require("firebase-functions/v2/https");
const logger_1 = require("../../core/logger");
const openai_runtime_1 = require("./openai_runtime");
function resolveTtsConfig(requestedVoice) {
    const voice = typeof requestedVoice === "string" && requestedVoice.trim()
        ? requestedVoice.trim()
        : process.env.OPENAI_TTS_VOICE?.trim() || "alloy";
    return {
        model: process.env.OPENAI_TTS_MODEL?.trim() || "tts-1",
        voice,
        responseFormat: "mp3",
    };
}
function buildTtsTextHash(text, config) {
    return node_crypto_1.default
        .createHash("sha256")
        .update(`${config.model}|${config.voice}|${config.responseFormat}|${text}`)
        .digest("hex");
}
function mapTtsError(error) {
    const info = (0, openai_runtime_1.classifyOpenAiError)(error);
    logger_1.logger.error("openai.tts.failure", {
        openAiRequestId: info.requestId,
        status: info.status,
        code: info.code,
        timeout: info.timeout,
        retryable: info.retryable,
        quotaExhausted: info.quotaExhausted,
    });
    if (info.timeout) {
        return new https_1.HttpsError("deadline-exceeded", "AI_TIMEOUT", { retryable: true });
    }
    if (info.status === 429) {
        return new https_1.HttpsError("resource-exhausted", info.quotaExhausted ? "AI_QUOTA_EXHAUSTED" : "AI_RATE_LIMITED", { retryable: !info.quotaExhausted });
    }
    if (info.retryable) {
        return new https_1.HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", {
            retryable: true,
        });
    }
    return new https_1.HttpsError("internal", "AI_TTS_FAILED", { retryable: false });
}
async function generateTtsMp3(options) {
    const startedAtMs = Date.now();
    try {
        const response = await (0, openai_runtime_1.getOpenAiClient)().audio.speech.create({
            model: options.config.model,
            voice: options.config.voice,
            input: options.text,
            response_format: options.config.responseFormat,
        }, { timeout: 45_000, maxRetries: 1 });
        const buffer = Buffer.from(await response.arrayBuffer());
        if (!buffer.length) {
            throw new https_1.HttpsError("internal", "AI_TTS_EMPTY", { retryable: false });
        }
        const openAiRequestId = response._request_id || null;
        const durationMs = Date.now() - startedAtMs;
        logger_1.logger.info("openai.tts.success", {
            openAiRequestId,
            model: options.config.model,
            voice: options.config.voice,
            durationMs,
            sizeBytes: buffer.length,
        });
        return { buffer, openAiRequestId, durationMs };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError)
            throw error;
        throw mapTtsError(error);
    }
}
//# sourceMappingURL=tts_service.js.map