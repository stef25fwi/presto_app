import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { APP_BASE_URL } from "../../config/env";
import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";
import { createInAppNotification, sendPushToUser } from "../notifications/push";

function getOwnerId(data: Record<string, unknown> | undefined): string {
  if (!data) return "";
  return String(data.owner_id || data.ownerId || data.userId || data.uid || "");
}

function getTitle(data: Record<string, unknown> | undefined): string {
  return String(data?.title || "Votre annonce");
}

export function buildListingRouteUrl(sourceCollection: string, sourceId: string): string {
  if (sourceCollection === COLLECTIONS.listings) {
    return `${APP_BASE_URL}/listings/${sourceId}`;
  }
  return `${APP_BASE_URL}/offers/${sourceId}`;
}

function getCategory(data: Record<string, unknown> | undefined): string {
  return String(data?.category || "").trim();
}

async function notifyFavoriteCategoryUsers({
  offerId,
  offerData,
  ownerId,
}: {
  offerId: string;
  offerData: Record<string, unknown>;
  ownerId: string;
}): Promise<void> {
  const category = getCategory(offerData);
  if (!category) return;

  const [selectedSnap, legacySnap] = await Promise.all([
    db.collection(COLLECTIONS.users)
      .where("selectedFavoriteCategories", "array-contains", category)
      .limit(500)
      .get(),
    db.collection(COLLECTIONS.users)
      .where("favoriteCategories", "array-contains", category)
      .limit(500)
      .get(),
  ]);

  const recipients = new Set<string>();
  for (const doc of [...selectedSnap.docs, ...legacySnap.docs]) {
    if (doc.id && doc.id !== ownerId) {
      recipients.add(doc.id);
    }
  }

  if (recipients.size === 0) return;

  const title = getTitle(offerData);
  const routeName = buildListingRouteUrl(COLLECTIONS.listings, offerId)
    .replace(APP_BASE_URL, "");

  for (const userId of recipients) {
    const notificationId = `notif_favorite_listing_${offerId}_${userId}`;
    await Promise.all([
      createInAppNotification({
        notificationId,
        userId,
        title: `Nouvelle annonce dans ${category}`,
        message: title,
        type: "favorite_listing_new",
        routeName,
        offerId,
        data: {
          category,
        },
      }),
      sendPushToUser({
        userId,
        topic: "favorites",
        title: `Nouvelle annonce dans ${category}`,
        body: title,
        routeName,
        channelId: "ilipresto_activity",
        collapseKey: `favorite_offer_${offerId}`,
        data: {
          type: "favorite_listing_new",
          offerId,
          category,
          notificationId,
        },
      }),
    ]);
  }
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
      sourceCollection: LEGACY_COLLECTIONS.offers,
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
      sourceCollection: LEGACY_COLLECTIONS.offers,
      sourceId: offerId,
      ownerId,
      dedupeSeed: `listing.published:${offerId}`,
      payload: {
        listingTitle: getTitle(after),
        listingUrl: buildListingRouteUrl(LEGACY_COLLECTIONS.offers, offerId),
      },
    });
    await notifyFavoriteCategoryUsers({
      offerId,
      offerData: after,
      ownerId,
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
      sourceCollection: LEGACY_COLLECTIONS.offers,
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
      sourceCollection: LEGACY_COLLECTIONS.offers,
      sourceId: offerId,
      ownerId,
      dedupeSeed: `listing.published:${offerId}:${normalizeStatus(after)}`,
      payload: {
        listingTitle: getTitle(after),
        listingUrl: buildListingRouteUrl(LEGACY_COLLECTIONS.offers, offerId),
      },
    });
    await notifyFavoriteCategoryUsers({
      offerId,
      offerData: after,
      ownerId,
    });
  }

  if (!isRejectedStatus(before) && isRejectedStatus(after)) {
    await emitListingEvent({
      eventName: "listing.rejected",
      sourceCollection: LEGACY_COLLECTIONS.offers,
      sourceId: offerId,
      ownerId,
      dedupeSeed: `listing.rejected:${offerId}:${normalizeStatus(after)}`,
      payload: {
        listingTitle: getTitle(after),
        rejectionReason: String(after.rejectionReason || after.moderationReason || after.rejectedReason || "Annonce non conforme à la charte"),
        editUrl: buildListingRouteUrl(LEGACY_COLLECTIONS.offers, offerId),
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
      listingUrl: buildListingRouteUrl(COLLECTIONS.listings, listingId),
    },
  });

  await notifyFavoriteCategoryUsers({
    offerId: listingId,
    offerData: after,
    ownerId: getOwnerId(after),
  });
});
