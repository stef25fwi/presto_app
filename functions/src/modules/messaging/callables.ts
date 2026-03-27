import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";
import { COLLECTIONS } from "../../shared/constants";
import { refreshUnreadMessageCount } from "../notifications/counters";
import {
  computeConversationStatus,
  isConversationBlocked,
  isConversationFlagEnabledForUser,
  readConversationFlagMap,
} from "./state";

const MESSAGE_SEND_WINDOW_MS = 10 * 1000;
const MESSAGE_SEND_LIMIT = 6;
const DUPLICATE_MESSAGE_WINDOW_MS = 15 * 1000;

function requireAuthUid(request: { auth?: { uid?: string; token?: Record<string, unknown> } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "authentication required");
  }
  return uid;
}

function sanitizeConversationPart(value: string): string {
  return value.replaceAll("/", "_").trim();
}

function canonicalConversationId({
  offerId,
  currentUserId,
  otherUserId,
}: {
  offerId: string;
  currentUserId: string;
  otherUserId: string;
}): string {
  const participants = [sanitizeConversationPart(currentUserId), sanitizeConversationPart(otherUserId)].sort();
  return `offer_${sanitizeConversationPart(offerId)}__${participants.join("__")}`;
}

function normalizeParticipantName(...values: unknown[]): string {
  for (const value of values) {
    const normalized = String(value || "").trim();
    if (normalized) return normalized;
  }
  return "Utilisateur";
}

function readOfferOwnerId(data: Record<string, unknown>): string {
  for (const field of ["ownerId", "userId", "uid"]) {
    const value = String(data[field] || "").trim();
    if (value) return value;
  }
  return "";
}

function readUserDisplayName(data: Record<string, unknown> | undefined, ...fallbacks: unknown[]): string {
  return normalizeParticipantName(
    data?.displayName,
    data?.display_name,
    data?.name,
    ...fallbacks,
  );
}

function sanitizeMessageText(value: unknown): string {
  return String(value ?? "")
    .split("\n")
    .map((line) => line.replace(/\s+$/g, ""))
    .join("\n")
    .trim();
}

export function readConversationMessageCount(data: Record<string, unknown>): number {
  const rawCount = data.messageCount;
  if (typeof rawCount === "number" && Number.isFinite(rawCount) && rawCount > 0) {
    return Math.floor(rawCount);
  }

  return String(data.lastMessage || "").trim() !== "" ? 1 : 0;
}

function toDateOrNull(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "number" && Number.isFinite(value)) return new Date(value);
  return null;
}

async function loadConversationForParticipant(conversationId: string, currentUserId: string) {
  const convRef = db.collection(COLLECTIONS.conversations).doc(conversationId);
  const convSnap = await convRef.get();

  if (!convSnap.exists) {
    throw new HttpsError("not-found", "conversation not found");
  }

  const data = (convSnap.data() ?? {}) as Record<string, unknown>;
  const participants = Array.isArray(data.participants)
    ? data.participants.map((value) => String(value || "").trim()).filter(Boolean)
    : [];

  if (!participants.includes(currentUserId)) {
    throw new HttpsError("permission-denied", "not allowed to access this conversation");
  }

  return { convRef, data, participants };
}

export const ensureOfferConversation = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const offerId = String(request.data?.offerId || "").trim();
  const otherUserId = String(request.data?.otherUserId || "").trim();

  if (!offerId || !otherUserId) {
    throw new HttpsError("invalid-argument", "offerId and otherUserId are required");
  }

  if (currentUserId == otherUserId) {
    throw new HttpsError("failed-precondition", "cannot create a conversation with yourself");
  }

  const offerSnap = await db.collection(COLLECTIONS.offers).doc(offerId).get();
  if (!offerSnap.exists) {
    throw new HttpsError("not-found", "offer not found");
  }

  const offerData = (offerSnap.data() ?? {}) as Record<string, unknown>;
  const offerOwnerId = readOfferOwnerId(offerData);
  if (!offerOwnerId) {
    throw new HttpsError("failed-precondition", "offer owner is missing");
  }
  if (offerOwnerId != otherUserId) {
    throw new HttpsError("permission-denied", "conversation target does not match offer owner");
  }

  const offerTitle = String(offerData.title || request.data?.offerTitle || "").trim();
  if (!offerTitle) {
    throw new HttpsError("failed-precondition", "offer title is missing");
  }

  const [currentUserSnap, otherUserSnap] = await Promise.all([
    db.collection(COLLECTIONS.users).doc(currentUserId).get(),
    db.collection(COLLECTIONS.users).doc(otherUserId).get(),
  ]);

  const currentUserName = readUserDisplayName(
    currentUserSnap.data() as Record<string, unknown> | undefined,
    request.auth?.token?.name,
    request.auth?.token?.email,
    currentUserId,
  );
  const otherUserName = readUserDisplayName(
    otherUserSnap.data() as Record<string, unknown> | undefined,
    offerData.advertiserName,
    otherUserId,
  );

  const participantNames: Record<string, string> = {
    [currentUserId]: currentUserName,
    [otherUserId]: otherUserName,
  };

  const convCol = db.collection(COLLECTIONS.conversations);
  const existing = await convCol
    .where("participants", "array-contains", currentUserId)
    .where("offerId", "==", offerId)
    .limit(20)
    .get();

  for (const doc of existing.docs) {
    const docData = doc.data() as Record<string, unknown>;
    const participants = Array.isArray(docData.participants)
      ? docData.participants
        .map((value: unknown) => String(value || "").trim())
        .filter(Boolean)
      : [];
    if (!participants.includes(otherUserId)) continue;

    if (isConversationBlocked(docData)) {
      throw new HttpsError("failed-precondition", "conversation is blocked");
    }

    const archivedBy = {
      ...readConversationFlagMap(docData, "archivedBy"),
      [currentUserId]: false,
    };
    const blockedBy = readConversationFlagMap(docData, "blockedBy");

    await doc.ref.set({
      participantNames,
      otherUserName,
      [`archivedBy.${currentUserId}`]: false,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      ok: true,
      conversationId: doc.id,
      offerTitle,
    };
  }

  const conversationId = canonicalConversationId({ offerId, currentUserId, otherUserId });
  const participants = [currentUserId, otherUserId].sort();
  const convRef = convCol.doc(conversationId);

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(convRef);
    if (snap.exists) {
      transaction.set(convRef, {
        participantNames,
        otherUserName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return;
    }

    transaction.set(convRef, {
      offerId,
      offerTitle,
      participants,
      participantNames,
      otherUserName,
      status: "open",
      archivedBy: {},
      blockedBy: {},
      lastReadAt: {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: "",
      messageCount: 0,
      unreadCount: {
        [currentUserId]: 0,
        [otherUserId]: 0,
      },
    });
  });

  return {
    ok: true,
    conversationId,
    offerTitle,
  };
});

export const sendConversationMessage = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();
  const text = sanitizeMessageText(request.data?.text);

  if (!conversationId || !text) {
    throw new HttpsError("invalid-argument", "conversationId and text are required");
  }

  if (text.length > 4000) {
    throw new HttpsError("invalid-argument", "message is too long");
  }

  const canSend = await canProceedRateLimited(
    "msg_send",
    `${currentUserId}:${conversationId}`,
    MESSAGE_SEND_LIMIT,
    MESSAGE_SEND_WINDOW_MS,
  );
  if (!canSend) {
    throw new HttpsError("resource-exhausted", "too many messages sent too quickly");
  }

  const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);

  const latestMessageSnap = await convRef
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();
  const latestMessageDoc = latestMessageSnap.docs[0];
  if (latestMessageDoc) {
    const latestData = latestMessageDoc.data() as Record<string, unknown>;
    const latestSenderId = String(latestData.senderId || "").trim();
    const latestText = sanitizeMessageText(latestData.text);
    const latestCreatedAt = toDateOrNull(latestData.createdAt);
    if (
      latestSenderId === currentUserId &&
      latestText === text &&
      latestCreatedAt != null &&
      Date.now() - latestCreatedAt.getTime() <= DUPLICATE_MESSAGE_WINDOW_MS
    ) {
      return {
        ok: true,
        deduplicated: true,
        messageId: latestMessageDoc.id,
      };
    }
  }

  const senderUserSnap = await db.collection(COLLECTIONS.users).doc(currentUserId).get();
  const senderName = readUserDisplayName(
    senderUserSnap.data() as Record<string, unknown> | undefined,
    request.auth?.token?.name,
    request.auth?.token?.email,
    currentUserId,
  );

  const messageRef = convRef.collection("messages").doc();
  let participantsToRefresh: string[] = [];

  await db.runTransaction(async (transaction) => {
    const convSnap = await transaction.get(convRef);

    if (!convSnap.exists) {
      throw new HttpsError("not-found", "conversation not found");
    }

    const data = (convSnap.data() ?? {}) as Record<string, unknown>;
    const participants = Array.isArray(data.participants)
      ? data.participants.map((value) => String(value || "").trim()).filter(Boolean)
      : [];

    if (!participants.includes(currentUserId)) {
      throw new HttpsError("permission-denied", "not allowed to access this conversation");
    }

    if (isConversationBlocked(data)) {
      throw new HttpsError("failed-precondition", "conversation is blocked");
    }

    const isFirstMessage = readConversationMessageCount(data) === 0;

    transaction.set(messageRef, {
      text,
      senderId: currentUserId,
      senderName,
      isFirstMessage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const conversationUpdate: Record<string, unknown> = {
      lastMessage: text,
      lastSenderId: currentUserId,
      lastSenderName: senderName,
      status: "open",
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      messageCount: admin.firestore.FieldValue.increment(1),
      [`participantNames.${currentUserId}`]: senderName,
    };

    for (const participantId of participants) {
      conversationUpdate[`archivedBy.${participantId}`] = false;
      conversationUpdate[`unreadCount.${participantId}`] = participantId == currentUserId
        ? 0
        : admin.firestore.FieldValue.increment(1);
    }

    transaction.update(convRef, conversationUpdate);
    participantsToRefresh = participants;
  });

  await Promise.all(participantsToRefresh.map((participantId) => refreshUnreadMessageCount(participantId)));

  return {
    ok: true,
    messageId: messageRef.id,
  };
});

export const markConversationRead = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);
  await convRef.update({
    [`unreadCount.${currentUserId}`]: 0,
    [`lastReadAt.${currentUserId}`]: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await refreshUnreadMessageCount(currentUserId);

  return { ok: true };
});

export const archiveConversation = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = {
    ...readConversationFlagMap(data, "archivedBy"),
    [currentUserId]: true,
  };
  const blockedBy = readConversationFlagMap(data, "blockedBy");

  await convRef.update({
    [`archivedBy.${currentUserId}`]: true,
    status: computeConversationStatus(participants, archivedBy, blockedBy),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

export const unarchiveConversation = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = {
    ...readConversationFlagMap(data, "archivedBy"),
    [currentUserId]: false,
  };
  const blockedBy = readConversationFlagMap(data, "blockedBy");

  await convRef.update({
    [`archivedBy.${currentUserId}`]: false,
    status: computeConversationStatus(participants, archivedBy, blockedBy),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

export const blockConversation = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = readConversationFlagMap(data, "archivedBy");
  const blockedBy = {
    ...readConversationFlagMap(data, "blockedBy"),
    [currentUserId]: true,
  };

  await convRef.update({
    [`blockedBy.${currentUserId}`]: true,
    status: computeConversationStatus(participants, archivedBy, blockedBy),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

export const unblockConversation = onCall({ region: PROJECT_REGION }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
  if (!isConversationFlagEnabledForUser(data, "blockedBy", currentUserId)) {
    return { ok: true };
  }

  const archivedBy = readConversationFlagMap(data, "archivedBy");
  const blockedBy = {
    ...readConversationFlagMap(data, "blockedBy"),
    [currentUserId]: false,
  };

  await convRef.update({
    [`blockedBy.${currentUserId}`]: false,
    status: computeConversationStatus(participants, archivedBy, blockedBy),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});