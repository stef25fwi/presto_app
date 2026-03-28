import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";
import { APP_BASE_URL } from "../../config/env";
import { readConversationParticipants } from "./participants";

export const enqueueUnreadMessageReminders = onSchedule("every 2 hours", async () => {
  const now = Date.now();
  const threshold = now - 24 * 60 * 60 * 1000;

  let query = db
    .collection(COLLECTIONS.conversations)
    .where("lastMessageAt", "<=", threshold)
    .orderBy("lastMessageAt")
    .limit(200);
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  while (true) {
    const q = await query.get();
    if (q.empty) break;

    for (const doc of q.docs) {
      lastDoc = doc;
      const data = doc.data();
      const status = String(data.status || "open").toLowerCase();
      if (status !== "open" && status !== "active" && status.length > 0) continue;

      const participantIds = readConversationParticipants(data);
      const unreadCount = (data.unreadCount || data.unread_count || {}) as Record<string, unknown>;
      const reminderBucket = Math.floor(now / (12 * 60 * 60 * 1000));

      for (const uid of participantIds) {
        const userId = String(uid || "");
        if (!userId) continue;
        const unread = Number(unreadCount[userId] || 0);
        if (unread <= 0) continue;
        const user = await db.collection(COLLECTIONS.users).doc(userId).get();
        const email = String(user.data()?.email || "").trim();
        if (!email) continue;

        const eventId = `evt_conv_reminder_${doc.id}_${userId}_${reminderBucket}`;
        await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
          event_id: eventId,
          event_name: "conversation.pending_reminder_due",
          source_collection: COLLECTIONS.conversations,
          source_id: doc.id,
          recipient_user_id: userId,
          dedupe_key: sha256(`conversation.pending_reminder_due:${doc.id}:${userId}:${reminderBucket}`),
          occurred_at: now,
          payload: {
            recipient_email: email,
            conversationUrl: `${APP_BASE_URL}/messages/${doc.id}`,
          },
          status: "created",
        }, { merge: true });
      }
    }

    if (q.size < 200 || !lastDoc) break;
    query = db
      .collection(COLLECTIONS.conversations)
      .where("lastMessageAt", "<=", threshold)
      .orderBy("lastMessageAt")
      .startAfter(lastDoc)
      .limit(200);
  }
});
