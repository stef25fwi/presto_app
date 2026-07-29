"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifyServicePhoto = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const logger_1 = require("../../../core/logger");
const idempotency_1 = require("../../ai/idempotency");
const openai_runtime_1 = require("../../ai/openai_runtime");
const remote_media_1 = require("../../ai/remote_media");
const trade_taxonomy_1 = require("../../ai/trade_taxonomy");
if (firebase_admin_1.default.apps.length === 0)
    firebase_admin_1.default.initializeApp();
const MODEL = process.env.OPENAI_VISION_MODEL?.trim() || "gpt-4o-mini-2024-07-18";
const PROMPT_VERSION = "ilipresto-trade-photo-v3";
const SCHEMA_VERSION = "ilipresto-trade-photo-schema-v3";
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const RESPONSE_FORMAT = {
    type: "json_schema",
    json_schema: {
        name: "ilipresto_trade_photo_result",
        strict: true,
        schema: {
            type: "object",
            additionalProperties: false,
            properties: {
                metier: {
                    anyOf: [
                        { type: "string", enum: [...trade_taxonomy_1.VALID_TRADE_KEYS] },
                        { type: "null" },
                    ],
                },
                confidence: { type: "number", minimum: 0, maximum: 1 },
            },
            required: ["metier", "confidence"],
        },
    },
};
const SYSTEM_PROMPT = `Tu es un classificateur de services pour iliprestō.
Analyse l'image et identifie uniquement le métier ou service principal visible.
Utilise exclusivement la clé autorisée par le schéma.
Si aucun métier n'est suffisamment reconnaissable, renvoie metier=null et confidence=0.
N'invente pas de contexte absent de l'image.`;
function normalizeMimeType(value) {
    return typeof value === "string" ? value.trim().toLowerCase() : "";
}
function validateBase64(value, mimeType) {
    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_TYPE_UNSUPPORTED");
    }
    const normalized = value.replace(/\s+/g, "");
    const estimatedBytes = Math.floor((normalized.length * 3) / 4);
    if (!normalized || estimatedBytes <= 0) {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_EMPTY");
    }
    if (estimatedBytes > MAX_IMAGE_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
    }
    const actualBytes = Buffer.from(normalized, "base64").length;
    if (actualBytes <= 0) {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_EMPTY");
    }
    if (actualBytes > MAX_IMAGE_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
    }
    return normalized;
}
async function enforceRateLimit(uid) {
    const now = Date.now();
    const windowSeconds = 60;
    const bucket = Math.floor(now / (windowSeconds * 1000));
    const ref = firebase_admin_1.default
        .firestore()
        .collection("_rate_limits")
        .doc(`classify_service_photo_${uid}_${bucket}`);
    await firebase_admin_1.default.firestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const previous = snapshot.exists ? Number(snapshot.data()?.count || 0) : 0;
        const next = previous + 1;
        if (next > 10) {
            throw new https_1.HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
                retryable: true,
            });
        }
        transaction.set(ref, {
            uid,
            action: "classify_service_photo",
            bucket,
            count: next,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis((bucket + 1) * windowSeconds * 1000),
        }, { merge: true });
    });
}
function mapProviderError(error) {
    if (error instanceof https_1.HttpsError)
        return error;
    const info = (0, openai_runtime_1.classifyOpenAiError)(error);
    if (info.timeout) {
        return new https_1.HttpsError("deadline-exceeded", "AI_TIMEOUT", {
            retryable: true,
        });
    }
    if (info.status === 429) {
        return new https_1.HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
            retryable: !info.quotaExhausted,
        });
    }
    if (info.retryable) {
        return new https_1.HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", {
            retryable: true,
        });
    }
    return new https_1.HttpsError("internal", "AI_PROVIDER_ERROR", {
        retryable: false,
    });
}
exports.classifyServicePhoto = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.OPENAI_API_KEY],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (request) => {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
    }
    await enforceRateLimit(uid);
    const imageUrl = typeof request.data?.imageUrl === "string" && request.data.imageUrl.trim()
        ? request.data.imageUrl.trim()
        : null;
    const rawBase64 = typeof request.data?.imageBase64 === "string"
        ? request.data.imageBase64
        : "";
    const mimeType = normalizeMimeType(request.data?.mimeType) || "image/jpeg";
    const imageBase64 = rawBase64 ? validateBase64(rawBase64, mimeType) : null;
    if (!imageUrl && !imageBase64) {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_REQUIRED");
    }
    const requestId = (0, idempotency_1.deriveClientRequestId)([
        imageUrl || "inline",
        imageBase64 || "",
        mimeType,
        MODEL,
        PROMPT_VERSION,
        trade_taxonomy_1.TRADE_TAXONOMY_VERSION,
    ]);
    const operation = await (0, idempotency_1.runIdempotentOperation)({
        uid,
        operation: "classify_service_photo_v3",
        requestId,
        ttlMs: 7 * 24 * 60 * 60 * 1000,
        execute: async () => {
            const client = (0, openai_runtime_1.getOpenAiClient)();
            const startedAtMs = Date.now();
            const context = {
                operation: "classify_service_photo",
                requestId,
                model: MODEL,
                promptVersion: PROMPT_VERSION,
                schemaVersion: SCHEMA_VERSION,
                startedAtMs,
            };
            try {
                const verifiedRemote = imageUrl
                    ? await (0, remote_media_1.downloadVerifiedRemoteImage)({
                        url: imageUrl,
                        expectedBucket: firebase_admin_1.default.storage().bucket().name,
                        maxBytes: MAX_IMAGE_BYTES,
                    })
                    : null;
                const imageContentUrl = verifiedRemote?.dataUrl || `data:${mimeType};base64,${imageBase64}`;
                const response = await client.chat.completions.create({
                    model: MODEL,
                    max_tokens: 64,
                    temperature: 0,
                    response_format: RESPONSE_FORMAT,
                    messages: [
                        { role: "system", content: SYSTEM_PROMPT },
                        {
                            role: "user",
                            content: [
                                {
                                    type: "image_url",
                                    image_url: { url: imageContentUrl, detail: "low" },
                                },
                            ],
                        },
                    ],
                }, { timeout: 15_000, maxRetries: 1 });
                (0, openai_runtime_1.logOpenAiSuccess)(context, response);
                const content = response.choices[0]?.message?.content?.trim() || "";
                if (!content) {
                    throw new https_1.HttpsError("internal", "AI_OUTPUT_EMPTY", {
                        retryable: true,
                    });
                }
                const parsed = JSON.parse(content);
                const metier = typeof parsed.metier === "string" && trade_taxonomy_1.VALID_TRADE_KEY_SET.has(parsed.metier)
                    ? parsed.metier
                    : null;
                const rawConfidence = Number(parsed.confidence);
                const confidence = Number.isFinite(rawConfidence)
                    ? Math.max(0, Math.min(1, rawConfidence))
                    : 0;
                logger_1.logger.info("classifyServicePhoto", {
                    uid,
                    requestId,
                    metier,
                    confidence,
                    cacheHit: false,
                    taxonomyVersion: trade_taxonomy_1.TRADE_TAXONOMY_VERSION,
                    remoteSizeBytes: verifiedRemote?.sizeBytes ?? null,
                });
                return {
                    metier,
                    confidence,
                    taxonomyVersion: trade_taxonomy_1.TRADE_TAXONOMY_VERSION,
                };
            }
            catch (error) {
                if (!(error instanceof https_1.HttpsError))
                    (0, openai_runtime_1.logOpenAiFailure)(context, error);
                throw mapProviderError(error);
            }
        },
    });
    return operation.value;
});
//# sourceMappingURL=classify_service_photo.js.map