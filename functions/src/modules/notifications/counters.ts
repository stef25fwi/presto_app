import admin from "firebase-admin";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

const CONVERSATION_PRIMARY_PARTICIPANT_FIELD = "participantIds";

function safeNumber(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function readBoolMap(value: unknown): Record<string, boolean> {
  if (!value || typeof value != "object") return {};
  const out: Record<string, boolean> = {};
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    out[key] = item === true;
  }
  return out;
}

async function setInboxCounts(userId: string, unreadMessages: number, unreadNotifications: number): Promise<void> {
  await db.collection(COLLECTIONS.users).doc(userId).set({
    inboxCounts: {
      unreadMessages: Math.max(0, unreadMessages),
      unreadNotifications: Math.max(0, unreadNotifications),
      totalUnread: Math.max(0, unreadMessages) + Math.max(0, unreadNotifications),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, { merge: true });
}

export async function refreshUnreadMessageCount(userId: string): Promise<void> {
  const snapshot = await db.collection(COLLECTIONS.conversations)
    .where(CONVERSATION_PRIMARY_PARTICIPANT_FIELD, "array-contains", userId)
    .get();

  let unreadMessages = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const archivedBy = readBoolMap(data.archivedBy);
    const blockedBy = readBoolMap(data.blockedBy);
    const status = String(data.status || "").trim().toLowerCase();

    // Ignore conversations archived by this user or explicitly closed for this user.
    if (archivedBy[userId] === true || blockedBy[userId] === true || status == "closed") {
      continue;
    }

    const unreadMap = ((data.unreadCount || data.unread_count || {}) as Record<string, unknown>);
    unreadMessages += safeNumber(unreadMap[userId]);
  }

  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const inboxCounts = (userSnap.data()?.inboxCounts || {}) as Record<string, unknown>;
  const unreadNotifications = safeNumber(inboxCounts.unreadNotifications);

  await setInboxCounts(userId, unreadMessages, unreadNotifications);
}

export async function refreshUnreadNotificationCount(userId: string): Promise<void> {
  const notificationsSnap = await db
    .collection(COLLECTIONS.notifications)
    .where("userId", "==", userId)
    .where("read", "==", false)
    .get();

  const unreadNotifications = notificationsSnap.size;
  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const inboxCounts = (userSnap.data()?.inboxCounts || {}) as Record<string, unknown>;
  const unreadMessages = safeNumber(inboxCounts.unreadMessages);

  await setInboxCounts(userId, unreadMessages, unreadNotifications);
}