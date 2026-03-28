import admin from "firebase-admin";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

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
  const [currentSnap, legacySnap] = await Promise.all([
    db.collection(COLLECTIONS.conversations)
      .where("participants", "array-contains", userId)
      .get(),
    db.collection(COLLECTIONS.conversations)
      .where("participant_ids", "array-contains", userId)
      .get(),
  ]);

  const seen = new Set<string>();
  let unreadMessages = 0;

  for (const doc of [...currentSnap.docs, ...legacySnap.docs]) {
    if (seen.has(doc.id)) continue;
    seen.add(doc.id);
    const unreadMap = (doc.data().unreadCount || {}) as Record<string, unknown>;
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