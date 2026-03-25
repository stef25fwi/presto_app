import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

type ListingDoc = {
  ownerId: string;
  title: string;
  sourceCollection: string;
  renewUrl: string;
};

function normalizeOwnerId(data: Record<string, unknown>): string {
  return String(data.owner_id || data.ownerId || data.userId || data.uid || "");
}

function isPublishedStatus(data: Record<string, unknown>): boolean {
  const status = String(data.status || "").trim().toLowerCase();
  return status === "published" || status === "active" || data.isActive === true;
}

async function emitListingLifecycleEvent(
  eventName: "listing.expiring_soon" | "listing.expired",
  docId: string,
  listing: ListingDoc,
  dedupeSeed: string,
): Promise<void> {
  const user = await db.collection(COLLECTIONS.users).doc(listing.ownerId).get();
  const email = String(user.data()?.email || "").trim();
  if (!email) return;

  const now = Date.now();
  const eventId = `evt_${eventName.replace(/\./g, "_")}_${docId}_${Math.floor(now / (60 * 60 * 1000))}`;
  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: eventName,
    source_collection: listing.sourceCollection,
    source_id: docId,
    recipient_user_id: listing.ownerId,
    dedupe_key: sha256(dedupeSeed),
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

async function processCollection(
  collectionName: string,
  buildRenewUrl: (docId: string) => string,
  now: number,
  in72h: number,
): Promise<void> {
  const expiringQ = await db
    .collection(collectionName)
    .where("expires_at", ">=", now)
    .where("expires_at", "<=", in72h)
    .limit(200)
    .get();

  for (const doc of expiringQ.docs) {
    const data = doc.data() as Record<string, unknown>;
    if (!isPublishedStatus(data)) continue;

    const ownerId = normalizeOwnerId(data);
    if (!ownerId) continue;

    await emitListingLifecycleEvent(
      "listing.expiring_soon",
      doc.id,
      {
        ownerId,
        title: String(data.title || "Annonce"),
        sourceCollection: collectionName,
        renewUrl: buildRenewUrl(doc.id),
      },
      `listing.expiring_soon:${collectionName}:${doc.id}:${Math.floor(now / (24 * 60 * 60 * 1000))}`,
    );
  }

  const expiredQ = await db
    .collection(collectionName)
    .where("expires_at", "<=", now)
    .limit(200)
    .get();

  for (const doc of expiredQ.docs) {
    const data = doc.data() as Record<string, unknown>;
    const ownerId = normalizeOwnerId(data);
    if (!ownerId) continue;

    const status = String(data.status || "").trim().toLowerCase();
    if (!(status === "expired" || isPublishedStatus(data))) continue;

    await emitListingLifecycleEvent(
      "listing.expired",
      doc.id,
      {
        ownerId,
        title: String(data.title || "Annonce"),
        sourceCollection: collectionName,
        renewUrl: buildRenewUrl(doc.id),
      },
      `listing.expired:${collectionName}:${doc.id}:${Math.floor(now / (24 * 60 * 60 * 1000))}`,
    );
  }
}

export const enqueueExpiringListingEmails = onSchedule("every 1 hours", async () => {
  const now = Date.now();
  const in72h = now + 72 * 60 * 60 * 1000;
  await processCollection(COLLECTIONS.listings, (docId) => `https://presto.app/listings/${docId}/renew`, now, in72h);
  await processCollection(COLLECTIONS.offers, (docId) => `https://presto.app/offers/${docId}`, now, in72h);
});
