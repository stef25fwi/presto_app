import admin from "../../core/firebase_admin_compat";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { APP_BASE_URL } from "../../config/env";
import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";
import { sendPushToUser, createInAppNotification } from "../notifications/push";

const LISTING_EXPIRY_REMINDERS_COLLECTION = "listing_expiry_reminders";

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

export function hasPublishedListingRecords(records: Record<string, unknown>[]): boolean {
  return records.some((record) => isPublishedStatus(record));
}

function toMillis(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value === "object" && value && "toMillis" in value) {
    const candidate = (value as { toMillis?: () => number }).toMillis?.();
    if (typeof candidate === "number" && Number.isFinite(candidate) && candidate > 0) return candidate;
  }
  return 0;
}

async function userHasPublishedListing(userId: string): Promise<boolean> {
  const [listingsByOwnerId, listingsByOwnerUnderscore] = await Promise.all([
    db.collection(COLLECTIONS.listings).where("ownerId", "==", userId).limit(20).get(),
    db.collection(COLLECTIONS.listings).where("owner_id", "==", userId).limit(20).get(),
  ]);

  const listingRecords = [...listingsByOwnerId.docs, ...listingsByOwnerUnderscore.docs]
    .map((doc) => doc.data() as Record<string, unknown>);
  if (hasPublishedListingRecords(listingRecords)) {
    return true;
  }

  const [offersByOwnerId, offersByOwnerUnderscore] = await Promise.all([
    db.collection(LEGACY_COLLECTIONS.offers).where("ownerId", "==", userId).limit(20).get(),
    db.collection(LEGACY_COLLECTIONS.offers).where("owner_id", "==", userId).limit(20).get(),
  ]);

  const offerRecords = [...offersByOwnerId.docs, ...offersByOwnerUnderscore.docs]
    .map((doc) => doc.data() as Record<string, unknown>);
  return hasPublishedListingRecords(offerRecords);
}

async function emitFirstListingNotPublishedEvent({
  userId,
  draftId,
  draftTitle,
}: {
  userId: string;
  draftId: string;
  draftTitle: string;
}): Promise<void> {
  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const userData = userSnap.data() ?? {};
  const email = String(userData.email || "").trim();
  if (!email) return;

  const now = Date.now();
  const reminderBucket = Math.floor(now / (7 * 24 * 60 * 60 * 1000));
  const eventId = `evt_listing_first_not_published_${userId}_${reminderBucket}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "listing.first_not_published.reminder",
    source_collection: COLLECTIONS.listingDrafts,
    source_id: draftId,
    recipient_user_id: userId,
    dedupe_key: sha256(`listing.first_not_published.reminder:${userId}:${reminderBucket}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      firstName: String(userData.displayName || userData.display_name || "").trim().split(" ")[0] || "",
      publishUrl: `${APP_BASE_URL}/publier`,
      listingDraftTitle: draftTitle,
    },
    status: "created",
  }, { merge: true });
}

async function processDraftCollection(collectionName: string, emittedUsers: Set<string>, cutoffMs: number): Promise<void> {
  const draftsQ = await db.collection(collectionName)
    .where("status", "in", ["draft", "ready"])
    .limit(200)
    .get();

  for (const doc of draftsQ.docs) {
    const data = doc.data() as Record<string, unknown>;
    const userId = normalizeOwnerId(data);
    if (!userId || emittedUsers.has(userId)) continue;

    const createdAt = toMillis(data.createdAt ?? data.created_at ?? data.updatedAt ?? data.updated_at);
    if (!createdAt || createdAt > cutoffMs) continue;
    if (await userHasPublishedListing(userId)) continue;

    emittedUsers.add(userId);
    await emitFirstListingNotPublishedEvent({
      userId,
      draftId: doc.id,
      draftTitle: String(data.title || "Votre brouillon"),
    });
  }
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
  await processCollection(COLLECTIONS.listings, (docId) => `https://ilipresto.fr/listings/${docId}/renew`, now, in72h);
  await processCollection(LEGACY_COLLECTIONS.offers, (docId) => `https://ilipresto.fr/offers/${docId}`, now, in72h);
});

export const enqueueFirstListingNotPublishedReminders = onSchedule("every day 10:00", async () => {
  const cutoffMs = Date.now() - 24 * 60 * 60 * 1000;
  const emittedUsers = new Set<string>();

  await processDraftCollection(COLLECTIONS.listingDrafts, emittedUsers, cutoffMs);
  await processDraftCollection(LEGACY_COLLECTIONS.listingDrafts, emittedUsers, cutoffMs);
});

async function processExpiryPushCollection(
  collectionName: string,
  now: number,
  in4h: number,
): Promise<void> {
  const expiringQ = await db
    .collection(collectionName)
    .where("expires_at", ">=", now)
    .where("expires_at", "<=", in4h)
    .limit(200)
    .get();

  for (const doc of expiringQ.docs) {
    const data = doc.data() as Record<string, unknown>;
    if (!isPublishedStatus(data)) continue;

    const ownerId = normalizeOwnerId(data);
    if (!ownerId) continue;

    const dedupRef = db.collection(LISTING_EXPIRY_REMINDERS_COLLECTION).doc(`${collectionName}_${doc.id}`);
    const dedupSnap = await dedupRef.get();
    if (dedupSnap.exists && dedupSnap.data()?.fourHourPushSentAt) continue;

    const listingTitle = String(data.title || "Votre annonce");
    const pushTitle = "Votre annonce arrive à terme !";
    const pushBody = `"${listingTitle}" expire dans moins de 4 heures. Rendez-vous dans Gérer mes annonces.`;
    const notificationId = `listing_expiry_4h_${collectionName}_${doc.id}`;

    await dedupRef.set(
      { fourHourPushSentAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );

    await Promise.allSettled([
      sendPushToUser({
        userId: ownerId,
        topic: "listings",
        title: pushTitle,
        body: pushBody,
        channelId: "ilipresto_activity",
        routeName: "/mes-annonces",
      }),
      createInAppNotification({
        notificationId,
        userId: ownerId,
        title: pushTitle,
        message: pushBody,
        type: "listing_expiry",
        routeName: "/mes-annonces",
      }),
    ]);
  }
}

export const enqueueFourHourExpiryPushNotifications = onSchedule("every 1 hours", async () => {
  const now = Date.now();
  const in4h = now + 4 * 60 * 60 * 1000;
  await processExpiryPushCollection(COLLECTIONS.listings, now, in4h);
  await processExpiryPushCollection(LEGACY_COLLECTIONS.offers, now, in4h);
});
