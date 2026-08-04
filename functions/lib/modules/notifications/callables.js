"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.unregisterPushToken = exports.sendSelfTestNotification = exports.broadcastTestNotification = exports.registerPushToken = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const logger_1 = require("../../core/logger");
const constants_1 = require("../../shared/constants");
const admin_audit_1 = require("../marketplace/services/admin_audit");
const roles_1 = require("../marketplace/services/roles");
const push_1 = require("./push");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    return uid;
}
function sanitizeTokenDocId(token) {
    return token.replaceAll("/", "_");
}
exports.registerPushToken = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const userId = requireAuthUid(request);
    const token = String(request.data?.token || "").trim();
    const platform = String(request.data?.platform || "unknown").trim().slice(0, 32);
    if (token.length < 20) {
        throw new https_1.HttpsError("invalid-argument", "invalid push token");
    }
    const docId = sanitizeTokenDocId(token);
    const tokenRef = firestore_1.db
        .collection(constants_1.COLLECTIONS.users)
        .doc(userId)
        .collection(constants_1.COLLECTIONS.pushTokens)
        .doc(docId);
    await firestore_1.db.runTransaction(async (transaction) => {
        const snap = await transaction.get(tokenRef);
        transaction.set(tokenRef, {
            token,
            uid: userId,
            userId,
            platform,
            enabled: true,
            ...(snap.exists ? {} : { createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp() }),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    logger_1.logger.info("push_token_registered", {
        userId,
        tokenId: docId,
        platform,
        appCheck: request.app != null,
    });
    return { ok: true, tokenId: docId };
});
const BROADCAST_DEFAULT_TITLE = "Notification test";
const BROADCAST_DEFAULT_BODY = "Ceci est une notification test envoyée à tous les utilisateurs.";
exports.broadcastTestNotification = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    timeoutSeconds: 300,
    memory: "512MiB",
}, async (request) => {
    const token = request.auth?.token;
    if (!token) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const roles = (0, roles_1.extractRolesFromAuthToken)(token);
    (0, roles_1.requireAnyRole)(roles, ["admin", "superadmin"], "Admin access required");
    const title = (String(request.data?.title || "").trim() || BROADCAST_DEFAULT_TITLE).slice(0, 120);
    const body = (String(request.data?.body || "").trim() || BROADCAST_DEFAULT_BODY).slice(0, 500);
    const result = await (0, push_1.sendBroadcastPush)({
        title,
        body,
        channelId: "ilipresto_activity",
        collapseKey: "admin_broadcast_test",
        data: { kind: "admin_broadcast_test" },
    });
    logger_1.logger.info("admin_broadcast_test_sent", {
        actor: request.auth?.uid ?? "unknown",
        ...result,
    });
    // Une diffusion touche tous les destinataires : elle laisse une trace
    // nominative dans le journal d'administration, comme toute action
    // sensible du point 9.
    await (0, admin_audit_1.writeAdminActionLog)({
        actorId: request.auth?.uid ?? "unknown",
        actorRole: roles.includes("superadmin") ? "superadmin" : "admin",
        actionType: "broadcast_test_notification",
        targetType: "push_broadcast",
        targetId: "all_users",
        after: { title, body },
        metadata: { ...result },
    });
    return { ok: true, ...result };
});
exports.sendSelfTestNotification = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, timeoutSeconds: 30 }, async (request) => {
    const userId = requireAuthUid(request);
    // Compte les appareils enregistrés (enabled absent = actif) pour donner un
    // retour clair à l'UI.
    const tokensSnap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.users)
        .doc(userId)
        .collection(constants_1.COLLECTIONS.pushTokens)
        .get();
    const deviceCount = tokensSnap.docs.filter((doc) => doc.data().enabled !== false && String(doc.data().token || "").trim() !== "").length;
    if (deviceCount === 0) {
        throw new https_1.HttpsError("failed-precondition", "Aucun appareil enregistré. Active d'abord les notifications sur cet appareil.");
    }
    // Notification de test envoyée à TOUS les appareils de l'utilisateur,
    // en ignorant les préférences (action explicite de l'utilisateur).
    await (0, push_1.sendPushToUser)({
        userId,
        topic: "support",
        title: "Notification test ✅",
        body: "Si tu vois ce message sur l'écran verrouillé, les notifications fonctionnent.",
        channelId: "ilipresto_activity",
        collapseKey: "self_test_notification",
        ignorePreferences: true,
        data: { kind: "self_test_notification" },
    });
    logger_1.logger.info("self_test_notification_sent", { userId, deviceCount });
    return { ok: true, deviceCount };
});
exports.unregisterPushToken = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const userId = requireAuthUid(request);
    const token = String(request.data?.token || "").trim();
    if (!token) {
        throw new https_1.HttpsError("invalid-argument", "token is required");
    }
    const docId = sanitizeTokenDocId(token);
    await firestore_1.db
        .collection(constants_1.COLLECTIONS.users)
        .doc(userId)
        .collection(constants_1.COLLECTIONS.pushTokens)
        .doc(docId)
        .delete();
    return { ok: true };
});
//# sourceMappingURL=callables.js.map