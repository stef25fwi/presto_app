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
function normalizeSubscriptionPlan(value) {
    const normalized = String(value ?? "").trim().toLowerCase();
    if (normalized === "ilipresto_plus" || normalized === "iliprestoplus" || normalized === "ilipresto+") {
        return "ilipresto_plus";
    }
    if (normalized === "ilipro") {
        return "ilipro";
    }
    return "free";
}
const FREE_PLAN_MAX_FAVORITES = 5;
async function readSubscriptionConfigFreeAccessMode() {
    const [snakeCaseSnap, camelCaseSnap] = await Promise.all([
        firestore_1.db.collection("app_config").doc("subscriptions").get().catch(() => null),
        firestore_1.db.collection(constants_1.COLLECTIONS.appConfig).doc("subscriptions").get().catch(() => null),
    ]);
    const data = snakeCaseSnap?.data() ?? camelCaseSnap?.data() ?? {};
    return data.freeAccessMode !== false;
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
        const userFavoriteRef = userRef.collection("favorites").doc(listingId);
        const freeAccessMode = await readSubscriptionConfigFreeAccessMode();
        let active = false;
        await firestore_1.db.runTransaction(async (transaction) => {
            const [listingSnap, favoriteSnap, userFavoriteSnap, userSnap] = await Promise.all([
                transaction.get(listingRef),
                transaction.get(favoriteRef),
                transaction.get(userFavoriteRef),
                transaction.get(userRef),
            ]);
            const alreadyFavorite = favoriteSnap.exists || userFavoriteSnap.exists;
            if (alreadyFavorite) {
                active = false;
                transaction.delete(favoriteRef);
                transaction.delete(userFavoriteRef);
                if (listingSnap.exists) {
                    transaction.set(listingRef, {
                        favoriteCount: firebase_admin_1.default.firestore.FieldValue.increment(-1),
                        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                    }, { merge: true });
                }
                transaction.set(userRef, {
                    favoriteOffersUpdatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                    activeFavoritesCount: firebase_admin_1.default.firestore.FieldValue.increment(-1),
                }, { merge: true });
                return;
            }
            if (!listingSnap.exists) {
                throw new https_1.HttpsError("not-found", "Listing not found");
            }
            const listingData = (listingSnap.data() ?? {});
            if (normalizeString(listingData.status) !== "active" || normalizeString(listingData.visibility) !== "public") {
                throw new https_1.HttpsError("failed-precondition", "Only public active listings can be favorited");
            }
            if (!freeAccessMode) {
                const userData = (userSnap.data() ?? {});
                const plan = normalizeSubscriptionPlan(userData.subscriptionPlan);
                const currentFavoritesCount = Number(userData.activeFavoritesCount || 0);
                if (plan === "free" && currentFavoritesCount >= FREE_PLAN_MAX_FAVORITES) {
                    throw new https_1.HttpsError("resource-exhausted", "free plan is limited to 5 favorites", { reason: "free_plan_favorites_limit_reached" });
                }
            }
            active = true;
            transaction.set(favoriteRef, {
                id: favoriteId,
                userId,
                listingId,
                offerId: listingId,
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            transaction.set(userFavoriteRef, {
                offerId: listingId,
                listingId,
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            transaction.set(listingRef, {
                favoriteCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            transaction.set(userRef, {
                favoriteOffersUpdatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                activeFavoritesCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
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