"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onListingPublished = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
exports.onListingPublished = (0, firestore_1.onDocumentUpdated)("listings/{listingId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const listingId = event.params.listingId;
    if (!after || before?.status === "published" || after.status !== "published")
        return;
    const ownerId = String(after.owner_id || "");
    if (!ownerId)
        return;
    const userSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get();
    const email = String(userSnap.data()?.email || "").trim();
    if (!email)
        return;
    const now = Date.now();
    const eventId = `evt_listing_published_${listingId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "listing.published",
        source_collection: constants_1.COLLECTIONS.listings,
        source_id: listingId,
        recipient_user_id: ownerId,
        dedupe_key: (0, hash_1.sha256)(`listing.published:${listingId}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            listingTitle: String(after.title || "Votre annonce"),
            listingUrl: `https://presto.app/listings/${listingId}`,
        },
        status: "created",
    });
});
//# sourceMappingURL=triggers.js.map