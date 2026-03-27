"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.unregisterPushToken = exports.registerPushToken = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
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
exports.registerPushToken = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const userId = requireAuthUid(request);
    const token = String(request.data?.token || "").trim();
    const platform = String(request.data?.platform || "unknown").trim().slice(0, 32);
    if (token.length < 20) {
        throw new https_1.HttpsError("invalid-argument", "invalid push token");
    }
    const docId = sanitizeTokenDocId(token);
    await firestore_1.db
        .collection(constants_1.COLLECTIONS.users)
        .doc(userId)
        .collection(constants_1.COLLECTIONS.pushTokens)
        .doc(docId)
        .set({
        token,
        platform,
        enabled: true,
        createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true, tokenId: docId };
});
exports.unregisterPushToken = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
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