import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

export const enqueueUnreadMessageReminders = onSchedule("every 2 hours", async () => {
  const now = Date.now();
  const threshold = now - 24 * 60 * 60 * 1000;

  const q = await db
    .collection(COLLECTIONS.conversations)
    .where("last_message_at", "<=", threshold)
    .where("status", "==", "open")
    .limit(200)
    .get();

  for (const doc of q.docs) {
    const data = doc.data();
    const participantIds = Array.isArray(data.participant_ids) ? data.participant_ids : [];

    for (const uid of participantIds) {
      const userId = String(uid || "");
      if (!userId) continue;
      const user = await db.collection(COLLECTIONS.users).doc(userId).get();
      const email = String(user.data()?.email || "").trim();
      if (!email) continue;

      const eventId = `evt_conv_reminder_${doc.id}_${userId}_${now}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "conversation.pending_reminder_due",
        source_collection: COLLECTIONS.conversations,
        source_id: doc.id,
        recipient_user_id: userId,
        dedupe_key: sha256(`conversation.pending_reminder_due:${doc.id}:${userId}:${Math.floor(now / (12 * 60 * 60 * 1000))}`),
        occurred_at: now,
        payload: {
          recipient_email: email,
          conversationUrl: `https://presto.app/messages/${doc.id}`,
        },
        status: "created",
      });
    }
  }
});
