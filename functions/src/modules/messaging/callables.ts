import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

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
    const participants = Array.isArray(doc.data().participants)
      ? doc.data().participants
        .map((value: unknown) => String(value || "").trim())
        .filter(Boolean)
      : [];
    if (!participants.includes(otherUserId)) continue;

    await doc.ref.set({
      participantNames,
      otherUserName,
      updatedAt: Date.now(),
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
        updatedAt: Date.now(),
      }, { merge: true });
      return;
    }

    transaction.set(convRef, {
      offerId,
      offerTitle,
      participants,
      participantNames,
      otherUserName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: Date.now(),
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: "",
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
  const text = String(request.data?.text || "").trim();

  if (!conversationId || !text) {
    throw new HttpsError("invalid-argument", "conversationId and text are required");
  }

  if (text.length > 4000) {
    throw new HttpsError("invalid-argument", "message is too long");
  }

  const { convRef, participants } = await loadConversationForParticipant(conversationId, currentUserId);
  const senderUserSnap = await db.collection(COLLECTIONS.users).doc(currentUserId).get();
  const senderName = readUserDisplayName(
    senderUserSnap.data() as Record<string, unknown> | undefined,
    request.auth?.token?.name,
    request.auth?.token?.email,
    currentUserId,
  );

  const messageRef = convRef.collection("messages").doc();
  const batch = db.batch();

  batch.set(messageRef, {
    text,
    senderId: currentUserId,
    senderName,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const conversationUpdate: Record<string, unknown> = {
    lastMessage: text,
    lastSenderId: currentUserId,
    lastSenderName: senderName,
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: Date.now(),
    [`participantNames.${currentUserId}`]: senderName,
  };

  for (const participantId of participants) {
    conversationUpdate[`unreadCount.${participantId}`] = participantId == currentUserId
      ? 0
      : admin.firestore.FieldValue.increment(1);
  }

  batch.update(convRef, conversationUpdate);
  await batch.commit();

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
    updatedAt: Date.now(),
  });

  return { ok: true };
});