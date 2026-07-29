"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminGetAiMetrics = void 0;
exports.estimateAiCostMicrosEur = estimateAiCostMicrosEur;
exports.recordAiMetric = recordAiMetric;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const logger_1 = require("../../core/logger");
const latency_histogram_1 = require("./latency_histogram");
const roles_1 = require("../marketplace/services/roles");
if (firebase_admin_1.default.apps.length === 0) {
    firebase_admin_1.default.initializeApp();
}
const COLLECTION = "_ai_metrics_daily";
function safeSegment(value) {
    return value
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9_.-]+/g, "_")
        .replace(/^_+|_+$/g, "")
        .slice(0, 80) || "unknown";
}
function dayKey(date = new Date()) {
    return date.toISOString().slice(0, 10);
}
function numericEnv(name) {
    const parsed = Number(process.env[name] || 0);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}
function estimateAiCostMicrosEur(input) {
    const inputRate = numericEnv("OPENAI_INPUT_EUR_PER_MILLION_TOKENS");
    const cachedRate = numericEnv("OPENAI_CACHED_INPUT_EUR_PER_MILLION_TOKENS");
    const outputRate = numericEnv("OPENAI_OUTPUT_EUR_PER_MILLION_TOKENS");
    const transcriptionRate = numericEnv("OPENAI_TRANSCRIPTION_EUR_PER_MINUTE");
    const inputTokens = Math.max(0, Number(input.inputTokens || 0));
    const cachedTokens = Math.min(inputTokens, Math.max(0, Number(input.cachedInputTokens || 0)));
    const uncachedTokens = inputTokens - cachedTokens;
    const outputTokens = Math.max(0, Number(input.outputTokens || 0));
    const audioMinutes = Math.max(0, Number(input.audioSeconds || 0)) / 60;
    const costEur = (uncachedTokens / 1_000_000) * inputRate +
        (cachedTokens / 1_000_000) * cachedRate +
        (outputTokens / 1_000_000) * outputRate +
        audioMinutes * transcriptionRate;
    return Math.max(0, Math.round(costEur * 1_000_000));
}
async function recordAiMetric(input) {
    const normalized = {
        ...input,
        operation: safeSegment(input.operation),
        model: safeSegment(input.model),
        pipelineVersion: safeSegment(input.pipelineVersion || "unknown"),
        durationMs: Math.max(0, Math.round(input.durationMs || 0)),
    };
    const id = [
        dayKey(),
        safeSegment(normalized.operation),
        safeSegment(normalized.provider),
        safeSegment(normalized.model),
        safeSegment(normalized.pipelineVersion || "unknown"),
    ].join("__");
    const ref = firebase_admin_1.default.firestore().collection(COLLECTION).doc(id);
    const costMicrosEur = estimateAiCostMicrosEur(normalized);
    const bucketField = (0, latency_histogram_1.latencyBucketField)(normalized.durationMs);
    const increments = {
        day: dayKey(),
        operation: normalized.operation,
        provider: normalized.provider,
        model: normalized.model,
        pipelineVersion: normalized.pipelineVersion || "unknown",
        count: firebase_admin_1.default.firestore.FieldValue.increment(1),
        successCount: firebase_admin_1.default.firestore.FieldValue.increment(normalized.success ? 1 : 0),
        failureCount: firebase_admin_1.default.firestore.FieldValue.increment(normalized.success ? 0 : 1),
        fallbackCount: firebase_admin_1.default.firestore.FieldValue.increment(normalized.fallbackUsed ? 1 : 0),
        cacheHitCount: firebase_admin_1.default.firestore.FieldValue.increment(normalized.cacheHit ? 1 : 0),
        totalDurationMs: firebase_admin_1.default.firestore.FieldValue.increment(normalized.durationMs),
        [bucketField]: firebase_admin_1.default.firestore.FieldValue.increment(1),
        totalInputTokens: firebase_admin_1.default.firestore.FieldValue.increment(Math.max(0, Number(normalized.inputTokens || 0))),
        totalCachedInputTokens: firebase_admin_1.default.firestore.FieldValue.increment(Math.max(0, Number(normalized.cachedInputTokens || 0))),
        totalOutputTokens: firebase_admin_1.default.firestore.FieldValue.increment(Math.max(0, Number(normalized.outputTokens || 0))),
        totalAudioSeconds: firebase_admin_1.default.firestore.FieldValue.increment(Math.max(0, Number(normalized.audioSeconds || 0))),
        estimatedCostMicrosEur: firebase_admin_1.default.firestore.FieldValue.increment(costMicrosEur),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(Date.now() + 120 * 24 * 60 * 60 * 1000),
    };
    if (normalized.errorCode) {
        increments.lastErrorCode = safeSegment(normalized.errorCode);
    }
    await ref.set(increments, { merge: true }).catch((error) => {
        logger_1.logger.warn("ai.metrics.write_failed", {
            operation: normalized.operation,
            model: normalized.model,
            errorName: error instanceof Error ? error.name : "Error",
        });
    });
}
exports.adminGetAiMetrics = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 20,
    memory: "256MiB",
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
    }
    const roles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token || {});
    (0, roles_1.requireAnyRole)(roles, ["admin", "superadmin"], "Admin access required");
    const requestedDays = Number(request.data?.days || 14);
    const days = Math.min(90, Math.max(1, Math.round(requestedDays)));
    const start = new Date(Date.now() - (days - 1) * 24 * 60 * 60 * 1000)
        .toISOString()
        .slice(0, 10);
    const snapshot = await firebase_admin_1.default
        .firestore()
        .collection(COLLECTION)
        .where("day", ">=", start)
        .orderBy("day", "desc")
        .limit(500)
        .get();
    const rows = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
    }));
    const totals = rows.reduce((acc, row) => {
        acc.count += Number(row.count || 0);
        acc.successCount += Number(row.successCount || 0);
        acc.failureCount += Number(row.failureCount || 0);
        acc.fallbackCount += Number(row.fallbackCount || 0);
        acc.cacheHitCount += Number(row.cacheHitCount || 0);
        acc.totalDurationMs += Number(row.totalDurationMs || 0);
        acc.estimatedCostMicrosEur += Number(row.estimatedCostMicrosEur || 0);
        return acc;
    }, {
        count: 0,
        successCount: 0,
        failureCount: 0,
        fallbackCount: 0,
        cacheHitCount: 0,
        totalDurationMs: 0,
        estimatedCostMicrosEur: 0,
    });
    const latencyBuckets = (0, latency_histogram_1.mergeLatencyBuckets)(rows);
    const percentiles = (0, latency_histogram_1.latencyPercentiles)(rows);
    return {
        days,
        rows,
        totals: {
            ...totals,
            successRate: totals.count > 0 ? totals.successCount / totals.count : null,
            averageDurationMs: totals.count > 0 ? Math.round(totals.totalDurationMs / totals.count) : null,
            estimatedCostEur: totals.estimatedCostMicrosEur / 1_000_000,
            latencyBuckets,
            latencyMs: percentiles,
        },
    };
});
//# sourceMappingURL=ai_metrics.js.map