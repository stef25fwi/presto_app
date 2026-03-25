"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueExpiringListingEmails = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
function normalizeOwnerId(data) {
    return String(data.owner_id || data.ownerId || data.userId || data.uid || "");
}
function isPublishedStatus(data) {
    const status = String(data.status || "").trim().toLowerCase();
    return status === "published" || status === "active" || data.isActive === true;
}
async function emitListingLifecycleEvent(eventName, docId, listing, dedupeSeed) {
    const user = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(listing.ownerId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email)
        return;
    const now = Date.now();
    const eventId = `evt_${eventName.replace(/\./g, "_")}_${docId}_${Math.floor(now / (60 * 60 * 1000))}`;
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: listing.sourceCollection,
        source_id: docId,
        recipient_user_id: listing.ownerId,
        dedupe_key: (0, hash_1.sha256)(dedupeSeed),
        occurred_at: now,
        payload: {
            recipient_email: email,
            listingTitle: listing.title,
            renewUrl: listing.renewUrl,
            listingUrl: listing.renewUrl,
        },
        status: "created",
    }, { merge: true });
}
async function processCollection(collectionName, buildRenewUrl, now, in72h) {
    const expiringQ = await firestore_1.db
        .collection(collectionName)
        .where("expires_at", ">=", now)
        .where("expires_at", "<=", in72h)
        .limit(200)
        .get();
    for (const doc of expiringQ.docs) {
        const data = doc.data();
        if (!isPublishedStatus(data))
            continue;
        const ownerId = normalizeOwnerId(data);
        if (!ownerId)
            continue;
        await emitListingLifecycleEvent("listing.expiring_soon", doc.id, {
            ownerId,
            title: String(data.title || "Annonce"),
            sourceCollection: collectionName,
            renewUrl: buildRenewUrl(doc.id),
        }, `listing.expiring_soon:${collectionName}:${doc.id}:${Math.floor(now / (24 * 60 * 60 * 1000))}`);
    }
    const expiredQ = await firestore_1.db
        .collection(collectionName)
        .where("expires_at", "<=", now)
        .limit(200)
        .get();
    for (const doc of expiredQ.docs) {
        const data = doc.data();
        const ownerId = normalizeOwnerId(data);
        if (!ownerId)
            continue;
        const status = String(data.status || "").trim().toLowerCase();
        if (!(status === "expired" || isPublishedStatus(data)))
            continue;
        await emitListingLifecycleEvent("listing.expired", doc.id, {
            ownerId,
            title: String(data.title || "Annonce"),
            sourceCollection: collectionName,
            renewUrl: buildRenewUrl(doc.id),
        }, `listing.expired:${collectionName}:${doc.id}:${Math.floor(now / (24 * 60 * 60 * 1000))}`);
    }
}
exports.enqueueExpiringListingEmails = (0, scheduler_1.onSchedule)("every 1 hours", async () => {
    const now = Date.now();
    const in72h = now + 72 * 60 * 60 * 1000;
    await processCollection(constants_1.COLLECTIONS.listings, (docId) => `https://presto.app/listings/${docId}/renew`, now, in72h);
    await processCollection(constants_1.COLLECTIONS.offers, (docId) => `https://presto.app/offers/${docId}`, now, in72h);
});
//# sourceMappingURL=scheduled.js.map