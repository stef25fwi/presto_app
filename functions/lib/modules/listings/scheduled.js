"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueExpiringListingEmails = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
exports.enqueueExpiringListingEmails = (0, scheduler_1.onSchedule)("every 1 hours", async () => {
    const now = Date.now();
    const in72h = now + 72 * 60 * 60 * 1000;
    const q = await firestore_1.db
        .collection(constants_1.COLLECTIONS.listings)
        .where("status", "==", "published")
        .where("expires_at", ">=", now)
        .where("expires_at", "<=", in72h)
        .limit(200)
        .get();
    for (const doc of q.docs) {
        const data = doc.data();
        const ownerId = String(data.owner_id || "");
        if (!ownerId)
            continue;
        const user = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get();
        const email = String(user.data()?.email || "").trim();
        if (!email)
            continue;
        const eventId = `evt_listing_expiring_${doc.id}_${now}`;
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "listing.expiring_soon",
            source_collection: constants_1.COLLECTIONS.listings,
            source_id: doc.id,
            recipient_user_id: ownerId,
            dedupe_key: (0, hash_1.sha256)(`listing.expiring_soon:${doc.id}:${Math.floor(now / (24 * 60 * 60 * 1000))}`),
            occurred_at: now,
            payload: {
                recipient_email: email,
                listingTitle: String(data.title || "Annonce"),
                renewUrl: `https://presto.app/listings/${doc.id}/renew`,
            },
            status: "created",
        });
    }
});
//# sourceMappingURL=scheduled.js.map