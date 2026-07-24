"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.reportClientMonitoringEvent = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const ALLOWED_LEVELS = new Set(["info", "warning", "error", "critical"]);
const MAX_DATA_KEYS = 20;
function boundedString(value, maxLength) {
    return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}
function sanitizeData(value) {
    if (!value || typeof value !== "object" || Array.isArray(value))
        return {};
    const blockedFragments = [
        "password",
        "token",
        "secret",
        "authorization",
        "apikey",
        "card",
        "iban",
    ];
    const result = {};
    for (const [rawKey, rawValue] of Object.entries(value).slice(0, MAX_DATA_KEYS)) {
        const key = boundedString(rawKey, 80);
        if (!key)
            continue;
        if (blockedFragments.some((fragment) => key.toLowerCase().includes(fragment))) {
            result[key] = "[redacted]";
            continue;
        }
        if (rawValue == null || typeof rawValue === "number" || typeof rawValue === "boolean") {
            result[key] = rawValue;
        }
        else {
            result[key] = boundedString(rawValue, 800);
        }
    }
    return result;
}
exports.reportClientMonitoringEvent = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
}, async (request) => {
    const uid = String(request.auth?.uid || "anonymous").trim() || "anonymous";
    const ip = boundedString(request.rawRequest.ip, 80) || "unknown";
    const rateKey = uid === "anonymous" ? `ip:${ip}` : `uid:${uid}`;
    const allowed = await (0, rate_limit_1.canProceedRateLimited)("client_monitoring", rateKey, 30, 60_000);
    if (!allowed) {
        throw new https_1.HttpsError("resource-exhausted", "monitoring rate limit exceeded");
    }
    const levelCandidate = boundedString(request.data?.level, 16).toLowerCase();
    const level = ALLOWED_LEVELS.has(levelCandidate) ? levelCandidate : "info";
    const scope = boundedString(request.data?.scope, 80);
    const action = boundedString(request.data?.action, 120);
    if (!scope || !action) {
        throw new https_1.HttpsError("invalid-argument", "scope and action are required");
    }
    await firestore_2.db.collection("app_monitoring_events").add({
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        createdAtClient: boundedString(request.data?.createdAtClient, 64) || null,
        level,
        scope,
        action,
        message: boundedString(request.data?.message, 800) || null,
        userId: uid,
        platform: boundedString(request.data?.platform, 40) || "unknown",
        releaseMode: request.data?.releaseMode === true,
        appBuild: boundedString(request.data?.appBuild, 80) || "unknown",
        gitCommit: boundedString(request.data?.gitCommit, 80) || "unknown",
        buildTime: boundedString(request.data?.buildTime, 80) || "unknown",
        data: sanitizeData(request.data?.data),
    });
    return { ok: true };
});
//# sourceMappingURL=callables.js.map