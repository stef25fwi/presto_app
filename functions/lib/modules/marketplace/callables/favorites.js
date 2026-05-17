"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.toggleFavorite = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const analytics_1 = require("../services/analytics");
const errors_1 = require("../services/errors");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function normalizeString(value) {
    return String(value ?? "").trim();
}
exports.toggleFavorite = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const userId = requireAuthUid(request);
    const listingId = normalizeString(request.data?.listingId);
    if (!listingId) {
        throw new https_1.HttpsError("invalid-argument", "listingId is required");
    }
    try {
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
        const favoriteId = `${userId}__${listingId}`;
        const favoriteRef = firestore_1.db.collection(constants_1.COLLECTIONS.favorites).doc(favoriteId);
        const userRef = firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId);
        let active = false;
        await firestore_1.db.runTransaction(async (transaction) => {
            const [listingSnap, favoriteSnap] = await Promise.all([
                transaction.get(listingRef),
                transaction.get(favoriteRef),
            ]);
            if (!listingSnap.exists) {
                throw new https_1.HttpsError("not-found", "Listing not found");
            }
            const listingData = (listingSnap.data() ?? {});
            if (normalizeString(listingData.status) !== "active" || normalizeString(listingData.visibility) !== "public") {
                throw new https_1.HttpsError("failed-precondition", "Only public active listings can be favorited");
            }
            if (favoriteSnap.exists) {
                active = false;
                transaction.delete(favoriteRef);
                transaction.set(listingRef, {
                    favoriteCount: firebase_admin_1.default.firestore.FieldValue.increment(-1),
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            else {
                active = true;
                transaction.set(favoriteRef, {
                    id: favoriteId,
                    userId,
                    listingId,
                    createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                });
                transaction.set(listingRef, {
                    favoriteCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            transaction.set(userRef, {
                favoriteOffersUpdatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        await (0, analytics_1.trackProductEventBackend)({
            eventName: active ? "listing_favorite_added" : "listing_favorite_removed",
            userId,
            listingId,
        });
        logger_1.logger.info("marketplace_favorite_toggled", {
            listingId,
            userId,
            active,
        });
        return {
            ok: true,
            active,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to toggle favorite");
    }
});
//# sourceMappingURL=favorites.js.map