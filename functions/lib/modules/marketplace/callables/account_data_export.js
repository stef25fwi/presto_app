"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.exportMyData = void 0;
exports.serializeFirestoreValue = serializeFirestoreValue;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const rate_limit_1 = require("../../../core/rate_limit");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const participants_1 = require("../../messaging/participants");
const errors_1 = require("../services/errors");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
// Firestore Timestamp instances aren't JSON-serializable as-is; convert them
// (and nested values) to ISO strings so the callable response is plain JSON.
function serializeFirestoreValue(value) {
    if (value === null || value === undefined) {
        return value;
    }
    if (typeof value === "object" && "toDate" in value &&
        typeof value.toDate === "function") {
        return value.toDate().toISOString();
    }
    if (Array.isArray(value)) {
        return value.map(serializeFirestoreValue);
    }
    if (typeof value === "object") {
        const result = {};
        for (const [key, entry] of Object.entries(value)) {
            result[key] = serializeFirestoreValue(entry);
        }
        return result;
    }
    return value;
}
function serializeDoc(doc) {
    return {
        id: doc.id,
        ...serializeFirestoreValue(doc.data() ?? {}),
    };
}
const EXPORT_QUERY_LIMIT = 500;
exports.exportMyData = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const uid = requireAuthUid(request);
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("account_data_export", uid, 3, 24 * 60 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many export requests today");
    }
    try {
        const [userSnap, proProfileSnap, proSnap, listingsSnap, reviewsSnap, ...conversationSnaps] = await Promise.all([
            firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(uid).get(),
            firestore_1.db.collection("pro_profiles").doc(uid).get(),
            firestore_1.db.collection(constants_1.COLLECTIONS.pros).doc(uid).get(),
            firestore_1.db.collection(constants_1.COLLECTIONS.listings).where("ownerId", "==", uid).limit(EXPORT_QUERY_LIMIT).get(),
            firestore_1.db.collection(constants_1.COLLECTIONS.reviews).where("reviewerId", "==", uid).limit(EXPORT_QUERY_LIMIT).get(),
            ...participants_1.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.map((field) => firestore_1.db.collection(constants_1.COLLECTIONS.conversations)
                .where(field, "array-contains", uid)
                .limit(EXPORT_QUERY_LIMIT)
                .get()),
        ]);
        const conversationsById = new Map();
        for (const snap of conversationSnaps) {
            for (const doc of snap.docs) {
                conversationsById.set(doc.id, serializeDoc(doc));
            }
        }
        const exportedAt = new Date().toISOString();
        logger_1.logger.info("account_data_export_completed", {
            uid,
            listingCount: listingsSnap.size,
            reviewCount: reviewsSnap.size,
            conversationCount: conversationsById.size,
        });
        return {
            ok: true,
            exportedAt,
            profile: userSnap.exists ? serializeDoc(userSnap) : null,
            proProfile: proProfileSnap.exists ? serializeDoc(proProfileSnap) : null,
            pro: proSnap.exists ? serializeDoc(proSnap) : null,
            listings: listingsSnap.docs.map(serializeDoc),
            reviews: reviewsSnap.docs.map(serializeDoc),
            conversations: Array.from(conversationsById.values()),
            note: "Cet export contient votre profil, vos annonces, vos avis et les métadonnées de vos " +
                "conversations (sans le contenu des messages). Pour le contenu détaillé d'une " +
                "conversation, contactez le support.",
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to export account data");
    }
});
//# sourceMappingURL=account_data_export.js.map