import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

function getOwnerId(data: Record<string, unknown> | undefined): string {
  if (!data) return "";
  return String(data.owner_id || data.ownerId || data.userId || data.uid || "");
}

function getTitle(data: Record<string, unknown> | undefined): string {
  return String(data?.title || "Votre annonce");
}

function getOfferUrl(sourceId: string): string {
  return `https://presto.app/offers/${sourceId}`;
}

function normalizeStatus(data: Record<string, unknown> | undefined): string {
  return String(data?.status || "").trim().toLowerCase();
}

function isPublishedStatus(data: Record<string, unknown> | undefined): boolean {
  const status = normalizeStatus(data);
  return status === "published" || status === "active" || data?.isActive === true;
}

function isSubmittedStatus(data: Record<string, unknown> | undefined): boolean {
  const status = normalizeStatus(data);
  return status === "submitted" || status === "in_moderation" || status === "pending_moderation";
}

function isRejectedStatus(data: Record<string, unknown> | undefined): boolean {
  const status = normalizeStatus(data);
  return status === "rejected" || status === "refused" || status === "declined";
}

async function emitListingEvent({
  eventName,
  sourceCollection,
  sourceId,
  ownerId,
  dedupeSeed,
  payload,
}: {
  eventName: "listing.submitted" | "listing.published" | "listing.rejected";
  sourceCollection: string;
  sourceId: string;
  ownerId: string;
  dedupeSeed: string;
  payload: Record<string, unknown>;
}): Promise<void> {
  if (!ownerId) return;

  const userSnap = await db.collection(COLLECTIONS.users).doc(ownerId).get();
  const email = String(userSnap.data()?.email || "").trim();
  if (!email) return;

  const now = Date.now();
  const eventId = `evt_${eventName.replace(/\./g, "_")}_${sourceId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: eventName,
    source_collection: sourceCollection,
    source_id: sourceId,
    recipient_user_id: ownerId,
    dedupe_key: sha256(dedupeSeed),
    occurred_at: now,
    payload: {
      recipient_email: email,
      ...payload,
    },
    status: "created",
  });
}

export const onOfferCreated = onDocumentCreated("offers/{offerId}", async (event) => {
  const after = event.data?.data() as Record<string, unknown> | undefined;
  if (!after) return;

  const offerId = event.params.offerId;
  const ownerId = getOwnerId(after);

  if (isSubmittedStatus(after)) {
    await emitListingEvent({
      eventName: "listing.submitted",
      sourceCollection: COLLECTIONS.offers,
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
      sourceCollection: COLLECTIONS.offers,
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

export const onOfferUpdated = onDocumentUpdated("offers/{offerId}", async (event) => {
  const before = event.data?.before.data() as Record<string, unknown> | undefined;
  const after = event.data?.after.data() as Record<string, unknown> | undefined;
  if (!after) return;

  const offerId = event.params.offerId;
  const ownerId = getOwnerId(after);

  if (!isSubmittedStatus(before) && isSubmittedStatus(after)) {
    await emitListingEvent({
      eventName: "listing.submitted",
      sourceCollection: COLLECTIONS.offers,
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
      sourceCollection: COLLECTIONS.offers,
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
      sourceCollection: COLLECTIONS.offers,
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

export const onListingPublished = onDocumentUpdated("listings/{listingId}", async (event) => {
  const before = event.data?.before.data() as Record<string, unknown> | undefined;
  const after = event.data?.after.data() as Record<string, unknown> | undefined;
  const listingId = event.params.listingId;

  if (!after || isPublishedStatus(before) || !isPublishedStatus(after)) return;

  await emitListingEvent({
    eventName: "listing.published",
    sourceCollection: COLLECTIONS.listings,
    sourceId: listingId,
    ownerId: getOwnerId(after),
    dedupeSeed: `listing.published:${listingId}`,
    payload: {
      listingTitle: getTitle(after),
      listingUrl: getOfferUrl(listingId),
    },
  });
});
