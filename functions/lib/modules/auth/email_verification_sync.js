"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncMyEmailVerification = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
exports.syncMyEmailVerification = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 30,
}, async (request) => {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    const userRecord = await firebase_admin_1.default.auth().getUser(uid);
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(uid).set({
        email: userRecord.email || null,
        emailVerified: userRecord.emailVerified === true,
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        ok: true,
        emailVerified: userRecord.emailVerified === true,
    };
});
//# sourceMappingURL=email_verification_sync.js.map