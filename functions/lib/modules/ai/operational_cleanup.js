"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.purgeExpiredAiOperationalData = exports.purgeExpiredAiAudio = void 0;
exports.scheduleAudioCleanup = scheduleAudioCleanup;
const node_crypto_1 = __importDefault(require("node:crypto"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../config/env");
const logger_1 = require("../../core/logger");
if (firebase_admin_1.default.apps.length === 0) {
    firebase_admin_1.default.initializeApp();
}
const AUDIO_CLEANUP_COLLECTION = "_ai_audio_cleanup";
const DEFAULT_AUDIO_RETENTION_MS = 30 * 60 * 1000;
function cleanupDocumentId(uid, storagePath) {
    return node_crypto_1.default
        .createHash("sha256")
        .update(`${uid}|${storagePath}`)
        .digest("hex");
}
async function scheduleAudioCleanup(options) {
    if (!options.storagePath)
        return;
    const retentionMs = Math.min(24 * 60 * 60 * 1000, Math.max(5 * 60 * 1000, options.retentionMs ?? DEFAULT_AUDIO_RETENTION_MS));
    const deleteAfter = firebase_admin_1.default.firestore.Timestamp.fromMillis(Date.now() + retentionMs);
    const id = cleanupDocumentId(options.uid, options.storagePath);
    await firebase_admin_1.default
        .firestore()
        .collection(AUDIO_CLEANUP_COLLECTION)
        .doc(id)
        .set({
        uid: options.uid,
        storagePath: options.storagePath,
        requestId: options.requestId,
        status: "scheduled",
        deleteAfter,
        expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(Date.now() + retentionMs + 7 * 24 * 60 * 60 * 1000),
        createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function deleteExpiredAudioBatch(limit = 100) {
    const now = firebase_admin_1.default.firestore.Timestamp.now();
    const snapshot = await firebase_admin_1.default
        .firestore()
        .collection(AUDIO_CLEANUP_COLLECTION)
        .where("deleteAfter", "<=", now)
        .orderBy("deleteAfter", "asc")
        .limit(limit)
        .get();
    let deleted = 0;
    for (const doc of snapshot.docs) {
        const data = doc.data();
        const storagePath = typeof data.storagePath === "string" ? data.storagePath : "";
        if (storagePath) {
            await firebase_admin_1.default
                .storage()
                .bucket()
                .file(storagePath)
                .delete({ ignoreNotFound: true })
                .catch((error) => {
                logger_1.logger.warn("ai.audio_cleanup.storage_delete_failed", {
                    documentId: doc.id,
                    errorName: error instanceof Error ? error.name : "Error",
                });
            });
        }
        await doc.ref.delete();
        deleted += 1;
    }
    return deleted;
}
async function purgeExpiredCollection(collection, limit = 250) {
    const snapshot = await firebase_admin_1.default
        .firestore()
        .collection(collection)
        .where("expiresAt", "<=", firebase_admin_1.default.firestore.Timestamp.now())
        .orderBy("expiresAt", "asc")
        .limit(limit)
        .get();
    if (snapshot.empty)
        return 0;
    const batch = firebase_admin_1.default.firestore().batch();
    for (const doc of snapshot.docs)
        batch.delete(doc.ref);
    await batch.commit();
    return snapshot.size;
}
exports.purgeExpiredAiAudio = (0, scheduler_1.onSchedule)({
    region: env_1.PROJECT_REGION,
    schedule: "every 15 minutes",
    timeZone: "Europe/Paris",
    timeoutSeconds: 120,
    memory: "256MiB",
}, async () => {
    let total = 0;
    for (let page = 0; page < 5; page += 1) {
        const count = await deleteExpiredAudioBatch(100);
        total += count;
        if (count < 100)
            break;
    }
    logger_1.logger.info("ai.audio_cleanup.completed", { deleted: total });
});
exports.purgeExpiredAiOperationalData = (0, scheduler_1.onSchedule)({
    region: env_1.PROJECT_REGION,
    schedule: "every day 03:35",
    timeZone: "Europe/Paris",
    timeoutSeconds: 180,
    memory: "256MiB",
}, async () => {
    const collections = [
        "_ai_idempotency",
        "_rate_limits",
        "_ai_metrics_daily",
        AUDIO_CLEANUP_COLLECTION,
    ];
    const deleted = {};
    for (const collection of collections) {
        let total = 0;
        for (let page = 0; page < 5; page += 1) {
            const count = await purgeExpiredCollection(collection);
            total += count;
            if (count < 250)
                break;
        }
        deleted[collection] = total;
    }
    logger_1.logger.info("ai.operational_cleanup.completed", { deleted });
});
//# sourceMappingURL=operational_cleanup.js.map