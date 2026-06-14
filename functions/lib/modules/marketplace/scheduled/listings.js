"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.publishApprovedListings = exports.expireOldListings = void 0;
exports.isListingReadyForScheduledPublication = isListingReadyForScheduledPublication;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const push_1 = require("../../notifications/push");
function normalizeString(value) {
    return String(value ?? "").trim();
}
function isListingReadyForScheduledPublication(data, now) {
    const autoPublishAfter = data.autoPublishAfter;
    const isDue = autoPublishAfter == null ||
        !(autoPublishAfter instanceof firebase_admin_1.default.firestore.Timestamp) ||
        autoPublishAfter.toMillis() <= now.toMillis();
    const moderationStatus = normalizeString(data.moderationStatus);
    const mediaProcessingStatus = normalizeString(data.mediaProcessingStatus);
    const moderationStatusAllowed = moderationStatus === "" ||
        moderationStatus === "approved";
    const mediaStatusAllowed = mediaProcessingStatus === "" ||
        mediaProcessingStatus === "completed";
    return normalizeString(data.status) === "pending" &&
        moderationStatusAllowed &&
        mediaStatusAllowed &&
        isDue;
}
exports.expireOldListings = (0, scheduler_1.onSchedule)({
    region: env_1.PROJECT_REGION,
    schedule: "every day 03:10",
    timeZone: "Europe/Paris",
}, async () => {
    const now = firebase_admin_1.default.firestore.Timestamp.now();
    const snapshot = await firestore_1.db.collection(constants_1.COLLECTIONS.listings)
        .where("status", "==", "active")
        .where("expiresAt", "<=", now)
        .limit(250)
        .get();
    if (snapshot.empty) {
        logger_1.logger.info("marketplace_expire_old_listings_noop");
        return;
    }
    const batch = firestore_1.db.batch();
    for (const doc of snapshot.docs) {
        const data = doc.data();
        batch.set(doc.ref, {
            status: "archived",
            visibility: "private",
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiredAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        const ownerId = String(data.ownerId || "").trim();
        if (ownerId) {
            await (0, push_1.createInAppNotification)({
                notificationId: `listing_expired_${doc.id}`,
                userId: ownerId,
                title: "Annonce expiree",
                message: String(data.title || "Votre annonce est archivee").trim() || "Votre annonce est archivee",
                type: "listing_expired",
                routeName: `/listings/${encodeURIComponent(doc.id)}`,
                offerId: doc.id,
            });
        }
    }
    await batch.commit();
    logger_1.logger.info("marketplace_expire_old_listings_done", { count: snapshot.size });
});
exports.publishApprovedListings = (0, scheduler_1.onSchedule)({
    region: env_1.PROJECT_REGION,
    schedule: "every minute",
    timeZone: "Europe/Paris",
}, async () => {
    const now = firebase_admin_1.default.firestore.Timestamp.now();
    const snapshot = await firestore_1.db.collection(constants_1.COLLECTIONS.listings)
        .where("status", "==", "pending")
        .limit(250)
        .get();
    const readyDocs = snapshot.docs.filter((doc) => isListingReadyForScheduledPublication(doc.data(), now));
    if (readyDocs.length === 0) {
        logger_1.logger.info("marketplace_publish_approved_listings_noop");
        return;
    }
    const batch = firestore_1.db.batch();
    for (const doc of readyDocs) {
        batch.set(doc.ref, {
            status: "active",
            visibility: "public",
            publishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            autoPublishAfter: null,
        }, { merge: true });
    }
    await batch.commit();
    logger_1.logger.info("marketplace_publish_approved_listings_done", { count: readyDocs.length });
});
//# sourceMappingURL=listings.js.map