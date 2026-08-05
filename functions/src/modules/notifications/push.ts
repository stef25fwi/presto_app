import admin from "../../core/firebase_admin_compat";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";

const FCM_MULTICAST_TOKEN_LIMIT = 500;

async function readUserTotalUnread(userId: string): Promise<number> {
  try {
    const snap = await db
      .collection(COLLECTIONS.users)
      .doc(userId)
      .collection("metadata")
      .doc("inbox")
      .get();
    const counts = (snap.data()?.inboxCounts ?? {}) as Record<string, unknown>;
    const n = Number(counts.totalUnread);
    return Number.isFinite(n) && n > 0 ? n : 0;
  } catch {
    return 0;
  }
}

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
  logger.info("push_invalid_tokens_cleaned", {
    userId,
    count: docIds.length,
  });
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
    await db.collection(COLLECTIONS.notifications).doc(notificationId).set({
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
    }, { merge: true });
  } catch (error) {
    const code = (error as { code?: number | string }).code;
    const codeText = String(code || "").toLowerCase();
    const isAlreadyExists = code == 6 || codeText == "6" || codeText == "already-exists";
    if (!isAlreadyExists) {
      throw error;
    }
  }
}

export async function sendBroadcastPush({
  title,
  body,
  channelId,
  routeName,
  collapseKey,
  data = {},
}: {
  title: string;
  body: string;
  channelId: "ilipresto_messages" | "ilipresto_activity";
  routeName?: string;
  collapseKey?: string;
  data?: Record<string, unknown>;
}): Promise<{ userCount: number; tokenCount: number; successCount: number; failureCount: number; totalUsers: number }> {
  // Nombre total d'utilisateurs (contexte pour l'admin: distinguer "aucun
  // appareil enregistré" de "aucun utilisateur").
  let totalUsers = 0;
  try {
    totalUsers = (await db.collection(COLLECTIONS.users).count().get()).data().count;
  } catch (error) {
    logger.warn("broadcast_push_user_count_failed", { error: String(error) });
  }

  // Collect every enabled push token across all users via a collection group query.
  const tokenToRef = new Map<string, FirebaseFirestore.DocumentReference>();
  const userIds = new Set<string>();

  const snap = await db.collectionGroup(COLLECTIONS.pushTokens).get();
  for (const doc of snap.docs) {
    const token = String(doc.data().token || "").trim();
    const enabled = doc.data().enabled !== false;
    if (!enabled || !token) continue;
    const userId = doc.ref.parent.parent?.id;
    if (userId) userIds.add(userId);
    if (!tokenToRef.has(token)) {
      tokenToRef.set(token, doc.ref);
    }
  }

  const tokens = Array.from(tokenToRef.keys());
  if (tokens.length === 0) {
    logger.warn("broadcast_push_no_tokens", { totalUsers });
    return { userCount: 0, tokenCount: 0, successCount: 0, failureCount: 0, totalUsers };
  }

  const invalidRefs: FirebaseFirestore.DocumentReference[] = [];
  let successCount = 0;
  let failureCount = 0;

  for (let index = 0; index < tokens.length; index += FCM_MULTICAST_TOKEN_LIMIT) {
    const batchTokens = tokens.slice(index, index + FCM_MULTICAST_TOKEN_LIMIT);
    const multicast = {
      tokens: batchTokens,
      notification: { title, body },
      data: toStringMap({ ...data, routeName, channelId }),
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
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default", contentAvailable: true } },
      },
      webpush: {
        notification: { icon: "/icons/Icon-192.png", badge: "/icons/Icon-192.png" },
        fcmOptions: {
          link: routeName ? `https://ilipresto.web.app${routeName}` : "https://ilipresto.web.app",
        },
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(multicast);
      successCount += response.successCount;
      failureCount += response.failureCount;
      response.responses.forEach((result, responseIndex) => {
        if (result.success) return;
        const code = result.error?.code || "";
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          const ref = tokenToRef.get(batchTokens[responseIndex]!);
          if (ref) invalidRefs.push(ref);
        }
      });
    } catch (error) {
      failureCount += batchTokens.length;
      logger.warn("broadcast_push_batch_failed", { error: String(error) });
    }
  }

  // Prune dead tokens so the next broadcast is cheaper and cleaner.
  for (let index = 0; index < invalidRefs.length; index += 400) {
    const batch = db.batch();
    for (const ref of invalidRefs.slice(index, index + 400)) {
      batch.delete(ref);
    }
    await batch.commit();
  }

  logger.info("broadcast_push_sent", {
    userCount: userIds.size,
    tokenCount: tokens.length,
    successCount,
    failureCount,
    invalidTokens: invalidRefs.length,
  });

  return { userCount: userIds.size, tokenCount: tokens.length, successCount, failureCount, totalUsers };
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
  ignorePreferences = false,
}: {
  userId: string;
  topic: PushTopic;
  title: string;
  body: string;
  routeName?: string;
  channelId: "ilipresto_messages" | "ilipresto_activity";
  collapseKey?: string;
  data?: Record<string, unknown>;
  ignorePreferences?: boolean;
}): Promise<void> {
  if (!ignorePreferences) {
    const enabled = await isPushEnabledForUser(userId, topic);
    if (!enabled) {
      logger.info("push_skipped_preferences_disabled", { userId, topic });
      return;
    }
  }

  const [tokenEntries, currentUnread] = await Promise.all([
    listPushTokens(userId),
    readUserTotalUnread(userId),
  ]);
  if (tokenEntries.length === 0) {
    logger.info("push_skipped_no_tokens", { userId, topic });
    return;
  }
  const invalidDocIds = new Set<string>();
  // +1 : le nouvel élément n'est pas encore comptabilisé dans le metadata.
  const badgeCount = currentUnread + 1;

  for (let index = 0; index < tokenEntries.length; index += FCM_MULTICAST_TOKEN_LIMIT) {
    const batchEntries = tokenEntries.slice(index, index + FCM_MULTICAST_TOKEN_LIMIT);
    const multicast = {
      tokens: batchEntries.map((entry) => entry.token),
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
            badge: badgeCount,
          },
        },
      },
      webpush: {
        notification: {
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
        },
        fcmOptions: {
          link: routeName ? `https://ilipresto.web.app${routeName}` : "https://ilipresto.web.app",
        },
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(multicast);
      logger.info("push_batch_sent", {
        userId,
        topic,
        tokenCount: batchEntries.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
      response.responses.forEach((result, responseIndex) => {
        if (result.success) return;

        const code = result.error?.code || "";
        logger.warn("push_token_send_failed", {
          userId,
          topic,
          tokenDocId: batchEntries[responseIndex]!.docId,
          code,
          message: result.error?.message || "",
        });
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          invalidDocIds.add(batchEntries[responseIndex]!.docId);
        }
      });
    } catch (error) {
      // Push should never break critical messaging workflows.
      logger.warn("push_send_batch_failed", {
        userId,
        topic,
        error: String(error),
      });
    }
  }

  await cleanupInvalidTokens(userId, Array.from(invalidDocIds));
}