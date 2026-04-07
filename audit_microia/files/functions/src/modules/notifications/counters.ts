import admin from "firebase-admin";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

const CONVERSATION_PRIMARY_PARTICIPANT_FIELD = "participants";

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
    const unreadMap = ((doc.data().unreadCount || doc.data().unread_count || {}) as Record<string, unknown>);
    unreadMessages += Number(unreadMap[userId] || 0);
  }

  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const inboxCounts = (userSnap.data()?.inboxCounts || {}) as Record<string, unknown>;
  const unreadNotifications = Number(inboxCounts.unreadNotifications || 0);

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
  const unreadMessages = Number(inboxCounts.unreadMessages || 0);

  await setInboxCounts(userId, unreadMessages, unreadNotifications);
}