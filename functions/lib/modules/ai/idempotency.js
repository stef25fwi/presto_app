"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeClientRequestId = normalizeClientRequestId;
exports.deriveClientRequestId = deriveClientRequestId;
exports.buildIdempotencyDocumentId = buildIdempotencyDocumentId;
exports.runIdempotentOperation = runIdempotentOperation;
const node_crypto_1 = __importDefault(require("node:crypto"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const logger_1 = require("../../core/logger");
if (firebase_admin_1.default.apps.length === 0) {
    firebase_admin_1.default.initializeApp();
}
const COLLECTION = "_ai_idempotency";
const IN_FLIGHT_MAX_AGE_MS = 2 * 60 * 1000;
const DEFAULT_TTL_MS = 24 * 60 * 60 * 1000;
function normalizeClientRequestId(value) {
    if (typeof value !== "string")
        return "";
    return value.trim().replace(/[^a-zA-Z0-9_.:-]/g, "_").slice(0, 180);
}
function deriveClientRequestId(parts) {
    const normalized = parts.map((part) => String(part ?? "").trim()).join("|");
    return node_crypto_1.default.createHash("sha256").update(normalized).digest("hex").slice(0, 40);
}
function buildIdempotencyDocumentId(uid, operation, requestId) {
    return node_crypto_1.default
        .createHash("sha256")
        .update(`${uid}|${operation}|${requestId}`)
        .digest("hex");
}
function isRetryableFailure(error) {
    if (error instanceof https_1.HttpsError) {
        return (error.code === "aborted" ||
            error.code === "deadline-exceeded" ||
            error.code === "resource-exhausted" ||
            error.code === "unavailable");
    }
    return false;
}
async function runIdempotentOperation(options) {
    const normalizedRequestId = normalizeClientRequestId(options.requestId);
    if (!normalizedRequestId) {
        return {
            value: await options.execute(),
            cacheHit: false,
            documentId: "",
        };
    }
    const now = Date.now();
    const ttlMs = Math.max(60_000, options.ttlMs ?? DEFAULT_TTL_MS);
    const documentId = buildIdempotencyDocumentId(options.uid, options.operation, normalizedRequestId);
    const ref = firebase_admin_1.default.firestore().collection(COLLECTION).doc(documentId);
    const cached = await firebase_admin_1.default.firestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const stored = snapshot.exists
            ? snapshot.data()
            : null;
        if (stored?.status === "completed" && stored.result) {
            return stored.result;
        }
        if (stored?.status === "processing" &&
            typeof stored.startedAtMs === "number" &&
            now - stored.startedAtMs < IN_FLIGHT_MAX_AGE_MS) {
            throw new https_1.HttpsError("aborted", "AI_REQUEST_IN_PROGRESS", { retryable: true, requestId: normalizedRequestId });
        }
        transaction.set(ref, {
            uid: options.uid,
            operation: options.operation,
            requestId: normalizedRequestId,
            status: "processing",
            startedAtMs: now,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(now + ttlMs),
        }, { merge: true });
        return null;
    });
    if (cached) {
        logger_1.logger.info("ai.idempotency.hit", {
            operation: options.operation,
            uid: options.uid,
            documentId,
        });
        return { value: cached, cacheHit: true, documentId };
    }
    try {
        const value = await options.execute();
        await ref.set({
            status: "completed",
            result: value,
            completedAtMs: Date.now(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(Date.now() + ttlMs),
        }, { merge: true });
        return { value, cacheHit: false, documentId };
    }
    catch (error) {
        await ref.set({
            status: "failed",
            retryable: isRetryableFailure(error),
            completedAtMs: Date.now(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(Date.now() + ttlMs),
        }, { merge: true }).catch(() => undefined);
        throw error;
    }
}
//# sourceMappingURL=idempotency.js.map