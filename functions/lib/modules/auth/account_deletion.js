"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestAccountDeletion = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const logger_1 = require("../../core/logger");
const account_deletion_cleanup_1 = require("./account_deletion_cleanup");
const RECENT_AUTH_MAX_AGE_SECONDS = 10 * 60;
const BATCH_WRITE_LIMIT = 400;
function requireRecentAuthenticatedUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    const authTime = Number(request.auth?.token?.auth_time || 0);
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (!Number.isFinite(authTime) ||
        authTime <= 0 ||
        nowSeconds - authTime > RECENT_AUTH_MAX_AGE_SECONDS) {
        throw new https_1.HttpsError("failed-precondition", "recent authentication required", { reason: "recent_authentication_required" });
    }
    return uid;
}
async function cancelStripeSubscription(subscriptionId) {
    const normalizedId = subscriptionId.trim();
    if (!normalizedId)
        return;
    const secret = env_1.STRIPE_SECRET_KEY.value().trim();
    if (!secret) {
        throw new https_1.HttpsError("failed-precondition", "Stripe is not configured");
    }
    const response = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(normalizedId)}`, {
        method: "DELETE",
        headers: {
            Authorization: `Bearer ${secret}`,
            "Content-Type": "application/x-www-form-urlencoded",
        },
    });
    if (response.ok || response.status === 404)
        return;
    const payload = await response.json().catch(() => ({}));
    throw new https_1.HttpsError("internal", payload.error?.message || `Stripe cancellation failed (${response.status})`);
}
async function commitDeletes(refs) {
    let batch = firestore_1.db.batch();
    let pending = 0;
    let deleted = 0;
    for (const ref of refs) {
        batch.delete(ref);
        pending += 1;
        deleted += 1;
        if (pending >= BATCH_WRITE_LIMIT) {
            await batch.commit();
            batch = firestore_1.db.batch();
            pending = 0;
        }
    }
    if (pending > 0)
        await batch.commit();
    return deleted;
}
async function queryRefs(collectionName, field, uid) {
    const snapshot = await firestore_1.db.collection(collectionName).where(field, "==", uid).get();
    return snapshot.docs.map((doc) => doc.ref);
}
async function deleteUserOwnedDocuments(uid) {
    const exactRefs = [
        firestore_1.db.collection("notification_preferences").doc(uid),
        firestore_1.db.collection("toolbox_journey_index").doc(uid),
    ];
    const querySpecs = [
        ["favorites", "userId"],
        ["notifications", "userId"],
        ["push_tokens", "userId"],
        ["listingDrafts", "ownerId"],
        ["parcours", "userId"],
        ["parcours", "ownerId"],
        ["toolbox_journeys", "userId"],
        ["toolbox_journeys", "ownerId"],
    ];
    const queriedRefs = await Promise.all(querySpecs.map(([collectionName, field]) => queryRefs(collectionName, field, uid)));
    const byPath = new Map();
    for (const ref of [...exactRefs, ...queriedRefs.flat()]) {
        byPath.set(ref.path, ref);
    }
    return commitDeletes(byPath.values());
}
async function anonymizeConversations(uid) {
    const snapshot = await firestore_1.db
        .collection("conversations")
        .where("participantIds", "array-contains", uid)
        .get();
    let batch = firestore_1.db.batch();
    let pending = 0;
    let updated = 0;
    for (const doc of snapshot.docs) {
        batch.set(doc.ref, {
            [`participantNames.${uid}`]: "Utilisateur supprimé",
            [`deletedBy.${uid}`]: true,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        pending += 1;
        updated += 1;
        if (pending >= BATCH_WRITE_LIMIT) {
            await batch.commit();
            batch = firestore_1.db.batch();
            pending = 0;
        }
    }
    if (pending > 0)
        await batch.commit();
    return updated;
}
async function deleteUserStorage(uid) {
    const bucket = firebase_admin_1.default.storage().bucket();
    const prefixes = [
        `profilePhotos/${uid}/`,
        `listingDrafts/${uid}/`,
        `messageAttachments/${uid}/`,
        `stt_streaming/${uid}/`,
    ];
    await Promise.all(prefixes.map((prefix) => bucket.deleteFiles({ prefix, force: true })));
    const [sttFiles] = await bucket.getFiles({ prefix: `stt/${uid}_` });
    await Promise.all(sttFiles.map((file) => file.delete({ ignoreNotFound: true })));
}
exports.requestAccountDeletion = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.STRIPE_SECRET_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 10,
}, async (request) => {
    const uid = requireRecentAuthenticatedUid(request);
    const userRef = firestore_1.db.collection("users").doc(uid);
    const userSnapshot = await userRef.get();
    const userData = userSnapshot.data() || {};
    const subscriptionId = String(userData.stripeSubscriptionId || userData.stripe_subscription_id || "").trim();
    await userRef.set({
        accountStatus: "deletion_processing",
        deletionRequestedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await cancelStripeSubscription(subscriptionId);
    const [deletedDocuments, anonymizedConversations, archivedListings] = await Promise.all([
        deleteUserOwnedDocuments(uid),
        anonymizeConversations(uid),
        (0, account_deletion_cleanup_1.archiveUserListings)(uid),
    ]);
    await deleteUserStorage(uid);
    await userRef.set({
        accountStatus: "deleted",
        deletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        email: null,
        displayName: "Utilisateur supprimé",
        fullName: null,
        firstName: null,
        lastName: null,
        pseudo: null,
        phoneNumber: null,
        photoUrl: null,
        photoURL: null,
        pendingEmail: null,
        stripeCustomerId: null,
        stripe_customer_id: null,
        stripeSubscriptionId: null,
        stripe_subscription_id: null,
        stripePriceId: null,
        stripe_price_id: null,
        subscriptionPlan: "free",
        subscriptionStatus: "canceled",
        deletionCompletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    try {
        await firebase_admin_1.default.auth().revokeRefreshTokens(uid);
        await firebase_admin_1.default.auth().deleteUser(uid);
    }
    catch (error) {
        const code = String(error.code || "");
        if (code !== "auth/user-not-found")
            throw error;
    }
    logger_1.logger.info("ACCOUNT_DELETION_COMPLETED", {
        uid,
        deletedDocuments,
        anonymizedConversations,
        archivedListings,
        stripeSubscriptionCanceled: Boolean(subscriptionId),
    });
    return {
        ok: true,
        deletedDocuments,
        anonymizedConversations,
        archivedListings,
    };
});
//# sourceMappingURL=account_deletion.js.map