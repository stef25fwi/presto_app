"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onListingPublished = exports.onOfferUpdated = exports.onOfferCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
function getOwnerId(data) {
    if (!data)
        return "";
    return String(data.owner_id || data.ownerId || data.userId || data.uid || "");
}
function getTitle(data) {
    return String(data?.title || "Votre annonce");
}
function getOfferUrl(sourceId) {
    return `https://presto.app/offers/${sourceId}`;
}
function normalizeStatus(data) {
    return String(data?.status || "").trim().toLowerCase();
}
function isPublishedStatus(data) {
    const status = normalizeStatus(data);
    return status === "published" || status === "active" || data?.isActive === true;
}
function isSubmittedStatus(data) {
    const status = normalizeStatus(data);
    return status === "submitted" || status === "in_moderation" || status === "pending_moderation";
}
function isRejectedStatus(data) {
    const status = normalizeStatus(data);
    return status === "rejected" || status === "refused" || status === "declined";
}
async function emitListingEvent({ eventName, sourceCollection, sourceId, ownerId, dedupeSeed, payload, }) {
    if (!ownerId)
        return;
    const userSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get();
    const email = String(userSnap.data()?.email || "").trim();
    if (!email)
        return;
    const now = Date.now();
    const eventId = `evt_${eventName.replace(/\./g, "_")}_${sourceId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: sourceCollection,
        source_id: sourceId,
        recipient_user_id: ownerId,
        dedupe_key: (0, hash_1.sha256)(dedupeSeed),
        occurred_at: now,
        payload: {
            recipient_email: email,
            ...payload,
        },
        status: "created",
    });
}
exports.onOfferCreated = (0, firestore_1.onDocumentCreated)("offers/{offerId}", async (event) => {
    const after = event.data?.data();
    if (!after)
        return;
    const offerId = event.params.offerId;
    const ownerId = getOwnerId(after);
    if (isSubmittedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.submitted",
            sourceCollection: constants_1.COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.submitted:${offerId}`,
            payload: {
                listingTitle: getTitle(after),
            },
        });
        return;
    }
    if (isPublishedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.published",
            sourceCollection: constants_1.COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.published:${offerId}`,
            payload: {
                listingTitle: getTitle(after),
                listingUrl: getOfferUrl(offerId),
            },
        });
    }
});
exports.onOfferUpdated = (0, firestore_1.onDocumentUpdated)("offers/{offerId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after)
        return;
    const offerId = event.params.offerId;
    const ownerId = getOwnerId(after);
    if (!isSubmittedStatus(before) && isSubmittedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.submitted",
            sourceCollection: constants_1.COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.submitted:${offerId}:${normalizeStatus(after)}`,
            payload: {
                listingTitle: getTitle(after),
            },
        });
    }
    if (!isPublishedStatus(before) && isPublishedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.published",
            sourceCollection: constants_1.COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.published:${offerId}:${normalizeStatus(after)}`,
            payload: {
                listingTitle: getTitle(after),
                listingUrl: getOfferUrl(offerId),
            },
        });
    }
    if (!isRejectedStatus(before) && isRejectedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.rejected",
            sourceCollection: constants_1.COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.rejected:${offerId}:${normalizeStatus(after)}`,
            payload: {
                listingTitle: getTitle(after),
                rejectionReason: String(after.rejectionReason || after.moderationReason || after.rejectedReason || "Annonce non conforme à la charte"),
                editUrl: getOfferUrl(offerId),
            },
        });
    }
});
exports.onListingPublished = (0, firestore_1.onDocumentUpdated)("listings/{listingId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const listingId = event.params.listingId;
    if (!after || isPublishedStatus(before) || !isPublishedStatus(after))
        return;
    await emitListingEvent({
        eventName: "listing.published",
        sourceCollection: constants_1.COLLECTIONS.listings,
        sourceId: listingId,
        ownerId: getOwnerId(after),
        dedupeSeed: `listing.published:${listingId}`,
        payload: {
            listingTitle: getTitle(after),
            listingUrl: getOfferUrl(listingId),
        },
    });
});
//# sourceMappingURL=triggers.js.map