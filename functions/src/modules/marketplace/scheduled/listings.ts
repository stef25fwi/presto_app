import admin from "../../../core/firebase_admin_compat";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export function isListingReadyForScheduledPublication(
  data: Record<string, unknown>,
  now: FirebaseFirestore.Timestamp,
): boolean {
  const autoPublishAfter = data.autoPublishAfter;
  const isDue =
    autoPublishAfter == null ||
    !(autoPublishAfter instanceof admin.firestore.Timestamp) ||
    autoPublishAfter.toMillis() <= now.toMillis();

  const moderationStatus = normalizeString(data.moderationStatus);
  const mediaProcessingStatus = normalizeString(data.mediaProcessingStatus);
  const moderationStatusAllowed = moderationStatus === "" ||
    moderationStatus === "approved";
  const mediaStatusAllowed = mediaProcessingStatus === "" ||
    mediaProcessingStatus === "completed";

  return normalizeString(data.status) === "pending" &&
    moderationStatusAllowed &&
    mediaStatusAllowed &&
    isDue;
}

export const expireOldListings = onSchedule({
  region: PROJECT_REGION,
  schedule: "every day 03:10",
  timeZone: "Europe/Paris",
}, async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await db.collection(COLLECTIONS.listings)
    .where("status", "==", "active")
    .where("expiresAt", "<=", now)
    .limit(250)
    .get();

  if (snapshot.empty) {
    logger.info("marketplace_expire_old_listings_noop");
    return;
  }

  const batch = db.batch();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    batch.set(doc.ref, {
      status: "archived",
      visibility: "private",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const ownerId = String(data.ownerId || "").trim();
    if (ownerId) {
      await createInAppNotification({
        notificationId: `listing_expired_${doc.id}`,
        userId: ownerId,
        title: "Annonce expiree",
        message: String(data.title || "Votre annonce est archivee").trim() || "Votre annonce est archivee",
        type: "listing_expired",
        routeName: `/listings/${encodeURIComponent(doc.id)}`,
        offerId: doc.id,
      });
    }
  }

  await batch.commit();
  logger.info("marketplace_expire_old_listings_done", { count: snapshot.size });
});

export const publishApprovedListings = onSchedule({
  region: PROJECT_REGION,
  schedule: "every minute",
  timeZone: "Europe/Paris",
}, async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await db.collection(COLLECTIONS.listings)
    .where("status", "==", "pending")
    .limit(250)
    .get();

  const readyDocs = snapshot.docs.filter((doc) =>
    isListingReadyForScheduledPublication(doc.data(), now),
  );

  if (readyDocs.length === 0) {
    logger.info("marketplace_publish_approved_listings_noop");
    return;
  }

  const batch = db.batch();
  for (const doc of readyDocs) {
    batch.set(doc.ref, {
      status: "active",
      visibility: "public",
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      autoPublishAfter: null,
    }, { merge: true });
  }

  await batch.commit();
  logger.info("marketplace_publish_approved_listings_done", { count: readyDocs.length });
});