import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";
import { trackProductEventBackend } from "../services/analytics";
import { toHttpsError } from "../services/errors";
import { verifyRecaptchaAssessment } from "../services/recaptcha";
import { validateChatMessageBody } from "../validators/listings";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function buildThreadId(listingId: string, participants: string[]): string {
  return `${listingId}__${participants.sort().join("__")}`;
}

export const createChatThreadFromListing = onCall({ region: PROJECT_REGION }, async (request) => {
  const senderId = requireAuthUid(request);
  const listingId = normalizeString(request.data?.listingId);
  const initialMessage = normalizeString(request.data?.message);
  const recaptchaToken = normalizeString(request.data?.recaptchaToken);

  if (!listingId) {
    throw new HttpsError("invalid-argument", "listingId is required");
  }
  if (!initialMessage) {
    throw new HttpsError("invalid-argument", "message is required");
  }

  const rateAllowed = await canProceedRateLimited("chat_thread_create", senderId, 10, 60 * 60 * 1000);
  if (!rateAllowed) {
    throw new HttpsError("resource-exhausted", "Too many chat threads created recently");
  }

  const recaptcha = await verifyRecaptchaAssessment({
    token: recaptchaToken,
    expectedAction: "message_create",
    userId: senderId,
  });
  if (!recaptcha.allowed) {
    throw new HttpsError("permission-denied", "reCAPTCHA rejected the first message");
  }

  try {
    const body = validateChatMessageBody(initialMessage);
    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const listingSnap = await listingRef.get();
    if (!listingSnap.exists) {
      throw new HttpsError("not-found", "Listing not found");
    }

    const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
    const ownerId = normalizeString(listingData.ownerId);
    if (!ownerId || ownerId === senderId) {
      throw new HttpsError("failed-precondition", "Cannot open a thread on your own listing");
    }

    const threadId = buildThreadId(listingId, [senderId, ownerId]);
    const threadRef = db.collection(COLLECTIONS.chatThreads).doc(threadId);
    const messageRef = threadRef.collection("messages").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
      const threadSnap = await transaction.get(threadRef);
      const unreadCountByUser = {
        [senderId]: 0,
        [ownerId]: 1,
      };

      if (!threadSnap.exists) {
        transaction.set(threadRef, {
          id: threadId,
          listingId,
          ownerId,
          buyerId: senderId,
          participants: [senderId, ownerId].sort(),
          status: "open",
          lastMessageAt: now,
          lastMessagePreview: body.slice(0, 160),
          unreadCountByUser,
          blockedBy: {},
          createdAt: now,
          updatedAt: now,
        });
      } else {
        transaction.set(threadRef, {
          lastMessageAt: now,
          lastMessagePreview: body.slice(0, 160),
          unreadCountByUser,
          updatedAt: now,
        }, { merge: true });
      }

      transaction.set(messageRef, {
        id: messageRef.id,
        threadId,
        listingId,
        senderId,
        body,
        moderationStatus: "clean",
        createdAt: now,
      });
    });

    await createInAppNotification({
      notificationId: `chat_message_${messageRef.id}`,
      userId: ownerId,
      title: "Nouveau message",
      message: body.slice(0, 120),
      type: "new_chat_message",
      routeName: `/chat/${encodeURIComponent(threadId)}`,
      conversationId: threadId,
      offerId: listingId,
    });

    await trackProductEventBackend({
      eventName: "listing_message_started",
      userId: senderId,
      listingId,
      threadId,
    });

    return {
      ok: true,
      threadId,
      messageId: messageRef.id,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to create chat thread");
  }
});

export const sendChatMessage = onCall({ region: PROJECT_REGION }, async (request) => {
  const senderId = requireAuthUid(request);
  const threadId = normalizeString(request.data?.threadId);
  if (!threadId) {
    throw new HttpsError("invalid-argument", "threadId is required");
  }

  const rateAllowed = await canProceedRateLimited("chat_message_send", senderId, 30, 5 * 60 * 1000);
  if (!rateAllowed) {
    throw new HttpsError("resource-exhausted", "Too many messages sent recently");
  }

  try {
    const body = validateChatMessageBody(request.data?.message);
    const threadRef = db.collection(COLLECTIONS.chatThreads).doc(threadId);
    const threadSnap = await threadRef.get();
    if (!threadSnap.exists) {
      throw new HttpsError("not-found", "Thread not found");
    }

    const threadData = (threadSnap.data() ?? {}) as Record<string, unknown>;
    const participants = Array.isArray(threadData.participants)
      ? threadData.participants.map((value) => normalizeString(value)).filter(Boolean)
      : [];
    if (!participants.includes(senderId)) {
      throw new HttpsError("permission-denied", "You are not a participant of this thread");
    }

    const blockedBy = (threadData.blockedBy ?? {}) as Record<string, unknown>;
    if (blockedBy[senderId] === true) {
      throw new HttpsError("failed-precondition", "Thread is blocked for this participant");
    }

    const recipientId = participants.find((participantId) => participantId !== senderId) || "";
    const messageRef = threadRef.collection("messages").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const unreadCountByUser = {
      ...(threadData.unreadCountByUser as Record<string, unknown> | undefined ?? {}),
      [senderId]: 0,
      [recipientId]: Number((threadData.unreadCountByUser as Record<string, unknown> | undefined ?? {})[recipientId] || 0) + 1,
    };

    await db.runTransaction(async (transaction) => {
      transaction.set(messageRef, {
        id: messageRef.id,
        threadId,
        listingId: normalizeString(threadData.listingId),
        senderId,
        body,
        moderationStatus: "clean",
        createdAt: now,
      });

      transaction.set(threadRef, {
        lastMessageAt: now,
        lastMessagePreview: body.slice(0, 160),
        unreadCountByUser,
        updatedAt: now,
      }, { merge: true });
    });

    if (recipientId) {
      await createInAppNotification({
        notificationId: `chat_message_${messageRef.id}`,
        userId: recipientId,
        title: "Nouveau message",
        message: body.slice(0, 120),
        type: "new_chat_message",
        routeName: `/chat/${encodeURIComponent(threadId)}`,
        conversationId: threadId,
        offerId: normalizeString(threadData.listingId),
      });
    }

    logger.info("marketplace_chat_message_sent", {
      threadId,
      senderId,
      messageId: messageRef.id,
    });

    return {
      ok: true,
      messageId: messageRef.id,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to send chat message");
  }
});