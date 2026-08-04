"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.publishPaymentInfoAudioDraft = exports.generatePaymentInfoAudioDraft = exports.generatePaymentInfoAudio = void 0;
const node_crypto_1 = __importDefault(require("node:crypto"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const logger_1 = require("../../core/logger");
const tts_service_1 = require("../ai/tts_service");
const admin_audit_1 = require("../marketplace/services/admin_audit");
const roles_1 = require("../marketplace/services/roles");
if (firebase_admin_1.default.apps.length === 0)
    firebase_admin_1.default.initializeApp();
const PUBLIC_CONFIG_DOC = "public_config/payment_info_audio";
const ADMIN_SETTINGS_DOC = "admin_settings/payment_info_audio";
const PUBLIC_STORAGE_PATH = "app_public/payment_audio/payment_info_current.mp3";
const DRAFT_STORAGE_PREFIX = "app_admin/payment_audio_drafts";
const DEFAULT_PAYMENT_TEXT = [
    "Bienvenue sur iliprestō.",
    "Cette fenêtre vous explique le fonctionnement du paiement.",
    "Vérifiez attentivement les informations affichées avant de confirmer.",
    "Si une option de paiement est disponible, suivez les étapes indiquées à l'écran.",
    "En cas de doute, vous pouvez revenir en arrière ou contacter l'assistance.",
].join(" ");
function cleanText(value) {
    const text = typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
    return text.slice(0, 2_500);
}
function requireAdmin(request) {
    const uid = cleanText(request.auth?.uid);
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
    const roles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token || {});
    (0, roles_1.requireAnyRole)(roles, ["admin", "superadmin"], "Admin access required");
    return uid;
}
function actorRole(request) {
    const roles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token || {});
    return roles.includes("superadmin") ? "superadmin" : "admin";
}
async function loadPaymentText(requestText) {
    const direct = cleanText(requestText);
    if (direct)
        return direct;
    const snapshot = await firebase_admin_1.default.firestore().doc(ADMIN_SETTINGS_DOC).get();
    const data = snapshot.data() || {};
    return (cleanText(data.text) ||
        cleanText(data.paymentText) ||
        cleanText(data.audioText) ||
        DEFAULT_PAYMENT_TEXT);
}
async function uploadMp3(options) {
    const version = Date.now();
    const storagePath = options.draft
        ? `${DRAFT_STORAGE_PREFIX}/${options.uid}_${version}.mp3`
        : PUBLIC_STORAGE_PATH;
    const token = node_crypto_1.default.randomUUID();
    await firebase_admin_1.default
        .storage()
        .bucket()
        .file(storagePath)
        .save(options.buffer, {
        resumable: false,
        validation: "crc32c",
        metadata: {
            contentType: "audio/mpeg",
            cacheControl: "public, max-age=3600",
            metadata: {
                firebaseStorageDownloadTokens: token,
                generatedBy: options.uid,
                version: String(version),
                draft: options.draft ? "true" : "false",
            },
        },
    });
    const bucketName = firebase_admin_1.default.storage().bucket().name;
    const audioUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
        `${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
    return {
        audioUrl,
        storagePath,
        contentType: "audio/mpeg",
        sizeBytes: options.buffer.length,
        version,
    };
}
exports.generatePaymentInfoAudio = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.OPENAI_API_KEY],
}, async (request) => {
    const uid = requireAdmin(request);
    const text = await loadPaymentText(request.data?.text);
    const config = (0, tts_service_1.resolveTtsConfig)(request.data?.voice);
    const textHash = (0, tts_service_1.buildTtsTextHash)(text, config);
    const publicRef = firebase_admin_1.default.firestore().doc(PUBLIC_CONFIG_DOC);
    const existing = (await publicRef.get()).data() || {};
    const existingUrl = cleanText(existing.audioUrl);
    if (existing.textHash === textHash && existingUrl) {
        logger_1.logger.info("openai.tts.cache_hit", {
            model: config.model,
            voice: config.voice,
            storagePath: existing.storagePath || PUBLIC_STORAGE_PATH,
        });
        return { ok: true, ...existing, reused: true };
    }
    const generated = await (0, tts_service_1.generateTtsMp3)({ text, config });
    const upload = await uploadMp3({ buffer: generated.buffer, uid, draft: false });
    const payload = {
        enabled: true,
        ...upload,
        generatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        generatedBy: uid,
        provider: "openai",
        model: config.model,
        voice: config.voice,
        textHash,
    };
    await publicRef.set(payload, { merge: true });
    await firebase_admin_1.default.firestore().doc(ADMIN_SETTINGS_DOC).set({
        text,
        paymentText: text,
        audioText: text,
        lastGeneratedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        lastPublishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        lastGeneratedBy: uid,
        lastPublishedBy: uid,
        lastStoragePath: upload.storagePath,
        lastVersion: upload.version,
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        ok: true,
        ...payload,
        generatedAt: new Date().toISOString(),
        reused: false,
    };
});
exports.generatePaymentInfoAudioDraft = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.OPENAI_API_KEY],
}, async (request) => {
    const uid = requireAdmin(request);
    const text = await loadPaymentText(request.data?.text);
    if (!text)
        throw new https_1.HttpsError("invalid-argument", "AUDIO_TEXT_REQUIRED");
    const config = (0, tts_service_1.resolveTtsConfig)(request.data?.voice);
    const textHash = (0, tts_service_1.buildTtsTextHash)(text, config);
    const settingsRef = firebase_admin_1.default.firestore().doc(ADMIN_SETTINGS_DOC);
    const existing = (await settingsRef.get()).data() || {};
    const existingUrl = cleanText(existing.draftAudioUrl);
    if (existing.draftTextHash === textHash && existingUrl) {
        logger_1.logger.info("openai.tts.draft_cache_hit", {
            model: config.model,
            voice: config.voice,
            storagePath: existing.draftStoragePath || null,
        });
        return { ok: true, ...existing, reused: true };
    }
    const generated = await (0, tts_service_1.generateTtsMp3)({ text, config });
    const upload = await uploadMp3({ buffer: generated.buffer, uid, draft: true });
    const payload = {
        text,
        paymentText: text,
        audioText: text,
        draftAudioUrl: upload.audioUrl,
        draftStoragePath: upload.storagePath,
        draftContentType: upload.contentType,
        draftSizeBytes: upload.sizeBytes,
        draftVersion: upload.version,
        draftGeneratedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        draftGeneratedBy: uid,
        draftProvider: "openai",
        draftModel: config.model,
        draftVoice: config.voice,
        draftTextHash: textHash,
        lastGeneratedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        lastGeneratedBy: uid,
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    };
    await settingsRef.set(payload, { merge: true });
    return {
        ok: true,
        ...payload,
        draftGeneratedAt: new Date().toISOString(),
        reused: false,
    };
});
exports.publishPaymentInfoAudioDraft = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = requireAdmin(request);
    const db = firebase_admin_1.default.firestore();
    const settingsRef = db.doc(ADMIN_SETTINGS_DOC);
    const data = (await settingsRef.get()).data() || {};
    const audioUrl = cleanText(data.draftAudioUrl);
    const storagePath = cleanText(data.draftStoragePath);
    if (!audioUrl || !storagePath) {
        throw new https_1.HttpsError("failed-precondition", "AUDIO_DRAFT_REQUIRED");
    }
    const payload = {
        enabled: true,
        audioUrl,
        storagePath,
        contentType: cleanText(data.draftContentType) || "audio/mpeg",
        sizeBytes: Number(data.draftSizeBytes || 0) || null,
        version: Number(data.draftVersion || Date.now()),
        generatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        generatedBy: uid,
        provider: "openai",
        model: cleanText(data.draftModel) || null,
        voice: cleanText(data.draftVoice) || null,
        textHash: cleanText(data.draftTextHash) || null,
    };
    await db.doc(PUBLIC_CONFIG_DOC).set(payload, { merge: true });
    await settingsRef.set({
        lastPublishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        lastPublishedBy: uid,
        lastStoragePath: storagePath,
        lastVersion: payload.version,
    }, { merge: true });
    logger_1.logger.info("openai.tts.draft_published", {
        uid,
        storagePath,
        version: payload.version,
    });
    // La publication rend l'audio visible des utilisateurs : c'est le
    // changement d'état qui doit rester traçable, pas la génération interne.
    await (0, admin_audit_1.writeAdminActionLog)({
        actorId: uid,
        actorRole: actorRole(request),
        actionType: "publish_payment_info_audio",
        targetType: "public_config",
        targetId: PUBLIC_CONFIG_DOC,
        after: { storagePath, version: payload.version, voice: payload.voice },
    });
    return { ok: true, ...payload, generatedAt: new Date().toISOString() };
});
//# sourceMappingURL=payment_info_audio.js.map