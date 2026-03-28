import admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";

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