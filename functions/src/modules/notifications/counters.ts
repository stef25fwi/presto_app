import admin from "../../core/firebase_admin_compat";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

const CONVERSATION_PRIMARY_PARTICIPANT_FIELD = "participantIds";
const INBOX_METADATA_COLLECTION = "metadata";
const INBOX_METADATA_DOC = "inbox";

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

function readInboxCounts(data: FirebaseFirestore.DocumentData | undefined): Record<string, unknown> {
  return ((data?.inboxCounts || {}) as Record<string, unknown>);
}

async function readCurrentInboxCounts(userId: string): Promise<Record<string, unknown>> {
  const userRef = db.collection(COLLECTIONS.users).doc(userId);
  const [userSnap, metadataSnap] = await Promise.all([
    userRef.get(),
    userRef.collection(INBOX_METADATA_COLLECTION).doc(INBOX_METADATA_DOC).get(),
  ]);
  return {
    ...readInboxCounts(userSnap.data()),
    ...readInboxCounts(metadataSnap.data()),
  };
}

async function setInboxCounts(userId: string, unreadMessages: number, unreadNotifications: number): Promise<void> {
  const inboxCounts = {
    inboxCounts: {
      unreadMessages: Math.max(0, unreadMessages),
      unreadNotifications: Math.max(0, unreadNotifications),
      totalUnread: Math.max(0, unreadMessages) + Math.max(0, unreadNotifications),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
  const userRef = db.collection(COLLECTIONS.users).doc(userId);
  const batch = db.batch();
  batch.set(userRef, inboxCounts, { merge: true });
  batch.set(userRef.collection(INBOX_METADATA_COLLECTION).doc(INBOX_METADATA_DOC), inboxCounts, { merge: true });
  await batch.commit();
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

  const inboxCounts = await readCurrentInboxCounts(userId);
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
  const inboxCounts = await readCurrentInboxCounts(userId);
  const unreadMessages = safeNumber(inboxCounts.unreadMessages);

  await setInboxCounts(userId, unreadMessages, unreadNotifications);
}