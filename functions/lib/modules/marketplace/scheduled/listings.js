"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.expireOldListings = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const push_1 = require("../../notifications/push");
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
//# sourceMappingURL=listings.js.map