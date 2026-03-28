"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifyListingRejected = exports.notifyListingApproved = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const logger_1 = require("../../../core/logger");
const push_1 = require("../../notifications/push");
const analytics_1 = require("../services/analytics");
function normalizeString(value) {
    return String(value ?? "").trim();
}
exports.notifyListingApproved = (0, firestore_1.onDocumentUpdated)("listings/{listingId}", async (event) => {
    const before = (event.data?.before.data() ?? {});
    const after = (event.data?.after.data() ?? {});
    const listingId = event.params.listingId;
    if (!after)
        return;
    const beforeStatus = normalizeString(before.status).toLowerCase();
    const afterStatus = normalizeString(after.status).toLowerCase();
    if (beforeStatus === afterStatus || afterStatus !== "active") {
        return;
    }
    const ownerId = normalizeString(after.ownerId);
    if (!ownerId)
        return;
    await (0, push_1.createInAppNotification)({
        notificationId: `listing_approved_trigger_${listingId}`,
        userId: ownerId,
        title: "Annonce approuvee",
        message: normalizeString(after.title) || "Votre annonce est en ligne.",
        type: "listing_approved",
        routeName: `/listings/${encodeURIComponent(listingId)}`,
        offerId: listingId,
    });
    await (0, analytics_1.trackProductEventBackend)({
        eventName: "listing_published",
        userId: ownerId,
        listingId,
        params: {
            source: "trigger",
        },
    });
    logger_1.logger.info("marketplace_listing_approved_notified", { listingId, ownerId });
});
exports.notifyListingRejected = (0, firestore_1.onDocumentUpdated)("listings/{listingId}", async (event) => {
    const before = (event.data?.before.data() ?? {});
    const after = (event.data?.after.data() ?? {});
    const listingId = event.params.listingId;
    if (!after)
        return;
    const beforeStatus = normalizeString(before.status).toLowerCase();
    const afterStatus = normalizeString(after.status).toLowerCase();
    if (beforeStatus === afterStatus || afterStatus !== "rejected") {
        return;
    }
    const ownerId = normalizeString(after.ownerId);
    if (!ownerId)
        return;
    await (0, push_1.createInAppNotification)({
        notificationId: `listing_rejected_trigger_${listingId}`,
        userId: ownerId,
        title: "Annonce rejetee",
        message: normalizeString(after.moderationReason) || "Votre annonce a ete rejetee.",
        type: "listing_rejected",
        routeName: `/listings/${encodeURIComponent(listingId)}`,
        offerId: listingId,
    });
    await (0, analytics_1.trackProductEventBackend)({
        eventName: "listing_rejected",
        userId: ownerId,
        listingId,
        params: {
            source: "trigger",
        },
    });
    logger_1.logger.info("marketplace_listing_rejected_notified", { listingId, ownerId });
});
//# sourceMappingURL=notifications.js.map