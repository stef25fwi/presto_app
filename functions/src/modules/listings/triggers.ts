import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

export const onListingPublished = onDocumentUpdated("listings/{listingId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const listingId = event.params.listingId;

  if (!after || before?.status === "published" || after.status !== "published") return;

  const ownerId = String(after.owner_id || "");
  if (!ownerId) return;

  const userSnap = await db.collection(COLLECTIONS.users).doc(ownerId).get();
  const email = String(userSnap.data()?.email || "").trim();
  if (!email) return;

  const now = Date.now();
  const eventId = `evt_listing_published_${listingId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "listing.published",
    source_collection: COLLECTIONS.listings,
    source_id: listingId,
    recipient_user_id: ownerId,
    dedupe_key: sha256(`listing.published:${listingId}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      listingTitle: String(after.title || "Votre annonce"),
      listingUrl: `https://presto.app/listings/${listingId}`,
    },
    status: "created",
  });
});
