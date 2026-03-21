import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

export const purgeOldEmailWebhooks = onSchedule("every day 04:00", async () => {
  const threshold = Date.now() - 30 * 24 * 60 * 60 * 1000;
  const q = await db.collection(COLLECTIONS.emailProviderWebhooks).where("received_at", "<", threshold).limit(500).get();
  for (const doc of q.docs) {
    await doc.ref.delete();
  }
});

export const purgeOldEmailLogs = onSchedule("every day 04:30", async () => {
  const threshold = Date.now() - 90 * 24 * 60 * 60 * 1000;
  const q = await db.collection(COLLECTIONS.emailLogs).where("created_at", "<", threshold).limit(500).get();
  for (const doc of q.docs) {
    await doc.ref.delete();
  }
});

export const syncEmailAnalytics = onSchedule("every 1 hours", async () => {
  await db.collection(COLLECTIONS.audits).add({
    action: "email.analytics.sync",
    created_at: Date.now(),
  });
});
