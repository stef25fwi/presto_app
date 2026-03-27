import admin from "firebase-admin";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

export type PushTopic = "messaging" | "favorites" | "support" | "listings" | "saved_searches";

function readBoolean(value: unknown, fallback = true): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function toStringMap(data: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    out[key] = String(value);
  }
  return out;
}

async function isPushEnabledForUser(userId: string, topic: PushTopic): Promise<boolean> {
  const prefsSnap = await db.collection(COLLECTIONS.notificationPreferences).doc(userId).get();
  const prefs = prefsSnap.data() as Record<string, unknown> | undefined;
  const pushPrefs = (prefs?.push as Record<string, unknown> | undefined) || {};
  const topicPrefs = (pushPrefs[topic] as Record<string, unknown> | undefined) || {};
  return readBoolean(topicPrefs.enabled, true);
}

async function listPushTokens(userId: string): Promise<Array<{ docId: string; token: string }>> {
  const snap = await db
    .collection(COLLECTIONS.users)
    .doc(userId)
    .collection(COLLECTIONS.pushTokens)
    .get();

  return snap.docs
    .map((doc) => {
      const token = String(doc.data().token || "").trim();
      const enabled = doc.data().enabled !== false;
      return enabled && token ? { docId: doc.id, token } : null;
    })
    .filter((entry): entry is { docId: string; token: string } => entry != null);
}

async function cleanupInvalidTokens(userId: string, docIds: string[]): Promise<void> {
  if (docIds.length === 0) return;

  const batch = db.batch();
  for (const docId of docIds) {
    batch.delete(
      db.collection(COLLECTIONS.users)
        .doc(userId)
        .collection(COLLECTIONS.pushTokens)
        .doc(docId),
    );
  }
  await batch.commit();
}

export async function createInAppNotification({
  notificationId,
  userId,
  title,
  message,
  type,
  routeName,
  conversationId,
  offerId,
  data = {},
}: {
  notificationId: string;
  userId: string;
  title: string;
  message: string;
  type: string;
  routeName?: string;
  conversationId?: string;
  offerId?: string;
  data?: Record<string, unknown>;
}): Promise<void> {
  try {
    await db.collection(COLLECTIONS.notifications).doc(notificationId).create({
      userId,
      title,
      message,
      type,
      routeName: routeName || null,
      conversationId: conversationId || null,
      offerId: offerId || null,
      data,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    const code = (error as { code?: number }).code;
    if (code !== 6) {
      throw error;
    }
  }
}

export async function sendPushToUser({
  userId,
  topic,
  title,
  body,
  routeName,
  channelId,
  collapseKey,
  data = {},
}: {
  userId: string;
  topic: PushTopic;
  title: string;
  body: string;
  routeName?: string;
  channelId: "ilipresto_messages" | "ilipresto_activity";
  collapseKey?: string;
  data?: Record<string, unknown>;
}): Promise<void> {
  const enabled = await isPushEnabledForUser(userId, topic);
  if (!enabled) return;

  const tokenEntries = await listPushTokens(userId);
  if (tokenEntries.length === 0) return;

  const multicast = {
    tokens: tokenEntries.map((entry) => entry.token),
    notification: {
      title,
      body,
    },
    data: toStringMap({
      ...data,
      routeName,
      channelId,
    }),
    android: {
      priority: "high" as const,
      collapseKey,
      notification: {
        channelId,
        tag: collapseKey,
        sound: "default",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
        },
      },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(multicast);
  const invalidDocIds: string[] = [];

  response.responses.forEach((result, index) => {
    if (result.success) return;

    const code = result.error?.code || "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      invalidDocIds.push(tokenEntries[index]!.docId);
    }
  });

  await cleanupInvalidTokens(userId, invalidDocIds);
}