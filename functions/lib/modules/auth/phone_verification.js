"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmPhoneVerified = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const logger_1 = require("../../core/logger");
const constants_1 = require("../../shared/constants");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
// Firebase Auth has no concept of a "linked but unverified" phone number —
// user.phoneNumber is only ever populated after a successful SMS code
// confirmation. Reading it via the Admin SDK (rather than trusting a client
// claim or ID token) is what makes this callable authoritative.
exports.confirmPhoneVerified = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const uid = requireAuthUid(request);
    const userRecord = await firebase_admin_1.default.auth().getUser(uid);
    const phoneNumber = String(userRecord.phoneNumber || "").trim();
    if (!phoneNumber) {
        throw new https_1.HttpsError("failed-precondition", "No verified phone number is linked to this account");
    }
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(uid).set({
        phone: phoneNumber,
        phoneVerified: true,
        phoneVerifiedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    logger_1.logger.info("account_phone_verified", { uid });
    return { ok: true, phone: phoneNumber };
});
//# sourceMappingURL=phone_verification.js.map