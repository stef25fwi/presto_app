import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

export const enqueueExpiringListingEmails = onSchedule("every 1 hours", async () => {
  const now = Date.now();
  const in72h = now + 72 * 60 * 60 * 1000;

  const q = await db
    .collection(COLLECTIONS.listings)
    .where("status", "==", "published")
    .where("expires_at", ">=", now)
    .where("expires_at", "<=", in72h)
    .limit(200)
    .get();

  for (const doc of q.docs) {
    const data = doc.data();
    const ownerId = String(data.owner_id || "");
    if (!ownerId) continue;

    const user = await db.collection(COLLECTIONS.users).doc(ownerId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email) continue;

    const eventId = `evt_listing_expiring_${doc.id}_${now}`;
    await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
      event_id: eventId,
      event_name: "listing.expiring_soon",
      source_collection: COLLECTIONS.listings,
      source_id: doc.id,
      recipient_user_id: ownerId,
      dedupe_key: sha256(`listing.expiring_soon:${doc.id}:${Math.floor(now / (24 * 60 * 60 * 1000))}`),
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
