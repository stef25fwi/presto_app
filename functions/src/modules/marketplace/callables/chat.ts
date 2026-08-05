import admin from "../../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { refreshUnreadMessageCount } from "../../notifications/counters";
import {
  CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES,
  readConversationParticipants,
} from "../../messaging/participants";
import { buildConversationMirrorFields, readConversationMirrorData } from "../../messaging/mirror";
import { isConversationBlocked } from "../../messaging/state";
import { trackProductEventBackend } from "../services/analytics";
import { toHttpsError } from "../services/errors";
import { shouldHardRejectForRecaptcha, verifyRecaptchaAssessment } from "../services/recaptcha";
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

function canonicalConversationId(listingId: string, participants: string[]): string {
  return `offer_${listingId.replaceAll("/", "_")}__${participants
    .map((value) => value.replaceAll("/", "_"))
    .sort()
    .join("__")}`;
}

function readListingOwnerId(listingData: Record<string, unknown>): string {
  return normalizeString(listingData.ownerId) ||
    normalizeString(listingData.userId) ||
    normalizeString(listingData.uid);
}

function normalizeDisplayName(...values: unknown[]): string {
  for (const value of values) {
    const normalized = normalizeString(value);
    if (normalized) return normalized;
  }
  return "Utilisateur";
}

async function findExistingConversationIdForListing(
  listingId: string,
  participantA: string,
  participantB: string,
): Promise<string | null> {
  const snapshots = await Promise.all(
    CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.flatMap((field) => [
      db.collection(COLLECTIONS.conversations)
        .where(field, "array-contains", participantA)
        .where("offerId", "==", listingId)
        .limit(20)
        .get(),
      db.collection(COLLECTIONS.conversations)
        .where(field, "array-contains", participantA)
        .where("offer_id", "==", listingId)
        .limit(20)
        .get(),
    ]),
  );

  const deduped = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      deduped.set(doc.id, doc);
    }
  }

  for (const doc of deduped.values()) {
    const participants = readConversationParticipants(
      (doc.data() ?? {}) as Record<string, unknown>,
      { conversationId: doc.id },
    );
    if (participants.includes(participantA) && participants.includes(participantB)) {
      return doc.id;
    }
  }

  return null;
}

async function appendConversationMessage({
  conversationId,
  senderId,
  senderName,
  body,
}: {
  conversationId: string;
  senderId: string;
  senderName: string;
  body: string;
}): Promise<{ messageId: string; listingId: string; participants: string[] }> {
  const convRef = db.collection(COLLECTIONS.conversations).doc(conversationId);
  const messageRef = convRef.collection("messages").doc();
  let participantsToRefresh: string[] = [];
  let listingId = "";

  await db.runTransaction(async (transaction) => {
    const convSnap = await transaction.get(convRef);
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "Conversation not found");
    }

    const data = (convSnap.data() ?? {}) as Record<string, unknown>;
    const participants = readConversationParticipants(data, { conversationId });
    if (!participants.includes(senderId)) {
      throw new HttpsError("permission-denied", "You are not a participant of this conversation");
    }
    if (isConversationBlocked(data)) {
      throw new HttpsError("failed-precondition", "Conversation is blocked");
    }

    const conversation = readConversationMirrorData(data, { conversationId });
    const isFirstMessage = Number(conversation.messageCount || 0) <= 0;
    listingId = normalizeString(conversation.offerId);

    transaction.set(messageRef, {
      text: body,
      body,
      senderId,
      sender_id: senderId,
      senderName,
      sender_name: senderName,
      isFirstMessage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const archivedBy = {
      ...conversation.archivedBy,
    };
    const unreadCount = {
      ...conversation.unreadCount,
    };

    for (const participantId of participants) {
      archivedBy[participantId] = false;
      unreadCount[participantId] = participantId === senderId
        ? 0
        : admin.firestore.FieldValue.increment(1);
    }

    transaction.set(
      convRef,
      buildConversationMirrorFields({
        ...conversation,
        participants,
        participantNames: {
          ...conversation.participantNames,
          [senderId]: senderName,
        },
        archivedBy,
        unreadCount,
        lastMessage: body,
        lastSenderId: senderId,
        lastSenderName: senderName,
        status: "open",
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      }),
      { merge: true },
    );

    participantsToRefresh = participants;
  });

  await Promise.all(participantsToRefresh.map((participantId) => refreshUnreadMessageCount(participantId)));
  return {
    messageId: messageRef.id,
    listingId,
    participants: participantsToRefresh,
  };
}

export const createChatThreadFromListing = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
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
  if (shouldHardRejectForRecaptcha(recaptcha)) {
    throw new HttpsError("permission-denied", "reCAPTCHA rejected the first message");
  }
  if (!recaptcha.allowed) {
    logger.warn("marketplace_chat_thread_recaptcha_non_blocking", {
      senderId,
      listingId,
      score: recaptcha.score,
      reasons: recaptcha.reasons,
      action: recaptcha.action,
      assessed: recaptcha.assessed,
    });
  }

  try {
    const body = validateChatMessageBody(initialMessage);
    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const listingSnap = await listingRef.get();
    if (!listingSnap.exists) {
      throw new HttpsError("not-found", "Listing not found");
    }

    const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
    const ownerId = readListingOwnerId(listingData);
    if (!ownerId || ownerId === senderId) {
      throw new HttpsError("failed-precondition", "Cannot open a thread on your own listing");
    }

    const existingConversationId = await findExistingConversationIdForListing(
      listingId,
      senderId,
      ownerId,
    );
    const conversationId = existingConversationId ?? canonicalConversationId(listingId, [senderId, ownerId]);

    if (!existingConversationId) {
      const [ownerUserSnap, senderUserSnap] = await Promise.all([
        db.collection(COLLECTIONS.users).doc(ownerId).get(),
        db.collection(COLLECTIONS.users).doc(senderId).get(),
      ]);

      const ownerData = (ownerUserSnap.data() ?? {}) as Record<string, unknown>;
      const senderData = (senderUserSnap.data() ?? {}) as Record<string, unknown>;

      await db.collection(COLLECTIONS.conversations).doc(conversationId).set(
        buildConversationMirrorFields({
          participants: [senderId, ownerId].sort(),
          participantNames: {
            [ownerId]: normalizeDisplayName(ownerData.displayName, ownerData.display_name, ownerData.name),
            [senderId]: normalizeDisplayName(senderData.displayName, senderData.display_name, senderData.name),
          },
          otherUserName: normalizeDisplayName(ownerData.displayName, ownerData.display_name, ownerData.name),
          offerId: listingId,
          offerTitle: normalizeString(listingData.title) || "Annonce IliPresto",
          status: "open",
          archivedBy: {},
          blockedBy: {},
          lastReadAt: {},
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: "",
          lastSenderId: "",
          lastSenderName: "",
          messageCount: 0,
          unreadCount: {
            [senderId]: 0,
            [ownerId]: 0,
          },
        }),
        { merge: true },
      );
    }

    const senderName = normalizeDisplayName(
      request.data?.senderName,
      request.auth?.token?.name,
      request.auth?.token?.email,
    );
    const { messageId } = await appendConversationMessage({
      conversationId,
      senderId,
      senderName,
      body,
    });

    await trackProductEventBackend({
      eventName: "listing_message_started",
      userId: senderId,
      listingId,
      threadId: conversationId,
    });

    return {
      ok: true,
      threadId: conversationId,
      messageId,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to create chat thread");
  }
});

export const sendChatMessage = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
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
    const senderName = normalizeDisplayName(
      request.data?.senderName,
      request.auth?.token?.name,
      request.auth?.token?.email,
    );
    const { messageId } = await appendConversationMessage({
      conversationId: threadId,
      senderId,
      senderName,
      body,
    });

    logger.info("marketplace_chat_message_sent", {
      threadId,
      senderId,
      messageId,
    });

    return {
      ok: true,
      messageId,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to send chat message");
  }
});