import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";
import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";
import { refreshUnreadMessageCount, refreshUnreadNotificationCount } from "../notifications/counters";
import {
  computeConversationStatus,
  isConversationBlocked,
  isConversationFlagEnabledForUser,
  readConversationFlagMap,
} from "./state";
import {
  CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES,
} from "./participants";
import {
  buildConversationMirrorFields,
  readConversationMessageCount,
  readConversationMirrorData,
} from "./mirror";

const MESSAGE_SEND_WINDOW_MS = 10 * 1000;
const MESSAGE_SEND_LIMIT = 6;
const DUPLICATE_MESSAGE_WINDOW_MS = 15 * 1000;

async function findConversationSnapshotsForParticipant(
  currentUserId: string,
  listingId?: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const conversationCollection = db.collection(COLLECTIONS.conversations);
  const listingFieldAliases = listingId ? ["listingId", "offerId", "offer_id"] as const : [null] as const;
  const snapshots = await Promise.all(
    CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.flatMap((participantField) =>
      listingFieldAliases.map((listingField) => {
        let query: FirebaseFirestore.Query = conversationCollection.where(
          participantField,
          "array-contains",
          currentUserId,
        );
        if (listingId && listingField) {
          query = query.where(listingField, "==", listingId);
        }
        return query.limit(20).get();
      }),
    ),
  );

  const deduped = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      deduped.set(doc.id, doc);
    }
  }
  return [...deduped.values()];
}

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

export function assertConversationParticipantAccess(
  participants: string[],
  currentUserId: string,
): void {
  if (!participants.includes(currentUserId)) {
    throw new HttpsError("permission-denied", "not allowed to access this conversation");
  }
}

async function deleteNotificationsForConversation(conversationId: string): Promise<Set<string>> {
  const routeName = `/messages/${encodeURIComponent(conversationId)}`;
  const [conversationIdSnap, routeNameSnap] = await Promise.all([
    db.collection(COLLECTIONS.notifications).where("conversationId", "==", conversationId).get(),
    db.collection(COLLECTIONS.notifications).where("routeName", "==", routeName).get(),
  ]);

  const notificationDocs = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const snapshot of [conversationIdSnap, routeNameSnap]) {
    for (const doc of snapshot.docs) {
      notificationDocs.set(doc.id, doc);
    }
  }

  if (notificationDocs.size == 0) {
    return new Set<string>();
  }

  let batch = db.batch();
  let batchCount = 0;
  const affectedUserIds = new Set<string>();

  for (const doc of notificationDocs.values()) {
    batch.delete(doc.ref);
    batchCount += 1;

    const userId = String(doc.data().userId || "").trim();
    if (userId) {
      affectedUserIds.add(userId);
    }

    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return affectedUserIds;
}

export function canonicalConversationId({
  listingId,
  currentUserId,
  otherUserId,
}: {
  listingId: string;
  currentUserId: string;
  otherUserId: string;
}): string {
  const participants = [sanitizeConversationPart(currentUserId), sanitizeConversationPart(otherUserId)].sort();
  return `conv_${sha256(`${sanitizeConversationPart(listingId)}::${participants.join("::")}`).slice(0, 32)}`;
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

export function resolveOfferLikeData({
  offerData,
  listingData,
}: {
  offerData?: Record<string, unknown> | null;
  listingData?: Record<string, unknown> | null;
}): {
  data: Record<string, unknown>;
  source: "offers" | "listings";
} {
  if (listingData != null) {
    return {data: listingData, source: "listings"};
  }

  if (offerData != null) {
    return {data: offerData, source: "offers"};
  }

  throw new HttpsError("not-found", "offer not found");
}

async function loadOfferLikeSnapshot(listingId: string): Promise<{
  data: Record<string, unknown>;
  source: "offers" | "listings";
}> {
  const listingSnap = await db.collection(COLLECTIONS.listings).doc(listingId).get();
  if (listingSnap.exists) {
    return {
      data: (listingSnap.data() ?? {}) as Record<string, unknown>,
      source: "listings",
    };
  }

  const offerSnap = await db.collection(LEGACY_COLLECTIONS.offers).doc(listingId).get();

  return resolveOfferLikeData({
    offerData: offerSnap.exists
      ? (offerSnap.data() ?? {}) as Record<string, unknown>
      : null,
    listingData: listingSnap.exists
      ? (listingSnap.data() ?? {}) as Record<string, unknown>
      : null,
  });
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

type ConversationAttachment = {
  type: "image" | "document";
  name: string;
  url: string;
  storagePath: string;
  mimeType: string;
  sizeBytes: number;
};

function sanitizeAttachmentText(value: unknown, maxLength: number): string {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function isAllowedDocumentAttachmentMimeType(mimeType: string): boolean {
  return mimeType.startsWith("text/") || [
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ].includes(mimeType);
}

export function sanitizeConversationAttachments(
  value: unknown,
  currentUserId: string,
  conversationId: string,
): ConversationAttachment[] {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "attachments must be an array");
  }
  if (value.length > 4) {
    throw new HttpsError("invalid-argument", "too many attachments");
  }

  return value.map((entry, index) => {
    if (!entry || typeof entry !== "object") {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} is invalid`);
    }
    const raw = entry as Record<string, unknown>;
    const type = sanitizeAttachmentText(raw.type, 24);
    if (type !== "image" && type !== "document") {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} type is invalid`);
    }

    const name = sanitizeAttachmentText(raw.name, 140) || (type === "image" ? "Photo" : "Document");
    const url = String(raw.url ?? "").trim();
    const storagePath = String(raw.storagePath ?? "").trim();
    const mimeType = sanitizeAttachmentText(raw.mimeType, 120);
    const sizeBytes = Number(raw.sizeBytes || 0);
    let parsedUrl: URL;
    try {
      parsedUrl = new URL(url);
    } catch (_) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} url is invalid`);
    }

    if (parsedUrl.protocol !== "https:" ||
      !["firebasestorage.googleapis.com", "storage.googleapis.com"].includes(parsedUrl.hostname) ||
      !storagePath.startsWith(`messageAttachments/${currentUserId}/${conversationId}/`)) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} storage is invalid`);
    }
    if (storagePath.includes("..") || storagePath.includes("\\") || storagePath.startsWith("/")) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} storage path is invalid`);
    }
    if (!mimeType || !Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > 20 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} metadata is invalid`);
    }
    if (type === "image" && !mimeType.startsWith("image/")) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} must be an image`);
    }
    if (type === "document" && !isAllowedDocumentAttachmentMimeType(mimeType)) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} document type is invalid`);
    }

    return {
      type,
      name,
      url,
      storagePath,
      mimeType,
      sizeBytes: Math.round(sizeBytes),
    };
  });
}

export function mergeConversationParticipants(
  existingParticipants: string[],
  requiredParticipants: string[],
): string[] {
  return [...existingParticipants, ...requiredParticipants]
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .filter((value, index, all) => all.indexOf(value) === index)
    .sort();
}

function toDateOrNull(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "number" && Number.isFinite(value)) return new Date(value);
  return null;
}

export function computeUnreadCountAfterMessageDeletion({
  participants,
  unreadCount,
  lastReadAt,
  deletedSenderId,
  deletedCreatedAt,
}: {
  participants: string[];
  unreadCount: Record<string, unknown>;
  lastReadAt: Record<string, unknown>;
  deletedSenderId: string;
  deletedCreatedAt: Date | null;
}): Record<string, number> {
  const result: Record<string, number> = {};

  for (const participantId of participants) {
    const currentUnread = Number(unreadCount[participantId] || 0);
    if (participantId === deletedSenderId || deletedCreatedAt == null) {
      result[participantId] = Math.max(0, currentUnread);
      continue;
    }

    const lastReadAtForParticipant = toDateOrNull(lastReadAt[participantId]);
    const shouldDecrement = !lastReadAtForParticipant || deletedCreatedAt > lastReadAtForParticipant;
    result[participantId] = Math.max(0, currentUnread - (shouldDecrement ? 1 : 0));
  }

  return result;
}

async function loadConversationForParticipant(conversationId: string, currentUserId: string) {
  const convRef = db.collection(COLLECTIONS.conversations).doc(conversationId);
  const convSnap = await convRef.get();

  if (!convSnap.exists) {
    throw new HttpsError("not-found", "conversation not found");
  }

  const data = (convSnap.data() ?? {}) as Record<string, unknown>;
  const conversation = readConversationMirrorData(data, { conversationId });
  const participants = conversation.participants;
  assertConversationParticipantAccess(participants, currentUserId);

  return { convRef, data, participants, conversation };
}

export const ensureOfferConversation = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const listingId = String(request.data?.listingId || request.data?.offerId || "").trim();
  const otherUserId = String(request.data?.otherUserId || "").trim();

  if (!listingId || !otherUserId) {
    throw new HttpsError("invalid-argument", "listingId and otherUserId are required");
  }

  if (currentUserId == otherUserId) {
    throw new HttpsError("failed-precondition", "cannot create a conversation with yourself");
  }

  const { data: offerData, source: offerSource } = await loadOfferLikeSnapshot(listingId);
  const offerOwnerId = readOfferOwnerId(offerData);
  if (!offerOwnerId) {
    throw new HttpsError("failed-precondition", `${offerSource} owner is missing`);
  }
  if (offerOwnerId != otherUserId) {
    throw new HttpsError("permission-denied", `conversation target does not match ${offerSource} owner`);
  }

  const offerTitle = String(
    offerData.listingTitle ||
    offerData.offerTitle ||
    offerData.title ||
    request.data?.listingTitle ||
    request.data?.offerTitle ||
    "",
  ).trim();
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
  const existingDocs = await findConversationSnapshotsForParticipant(currentUserId, listingId);

  for (const doc of existingDocs) {
    const docData = doc.data() as Record<string, unknown>;
    const conversation = readConversationMirrorData(docData, { conversationId: doc.id });
    if (!conversation.participants.includes(otherUserId)) continue;

    const normalizedParticipants = mergeConversationParticipants(
      conversation.participants,
      [currentUserId, otherUserId],
    );

    if (isConversationBlocked(docData)) {
      throw new HttpsError("failed-precondition", "conversation is blocked");
    }

    const archivedBy = {
      ...conversation.archivedBy,
      [currentUserId]: false,
    };
    const blockedBy = conversation.blockedBy;

    await doc.ref.set(
      buildConversationMirrorFields({
        ...conversation,
        participants: normalizedParticipants,
        participantNames: {
          ...conversation.participantNames,
          ...participantNames,
        },
        otherUserName,
        listingId,
        listingTitle: offerTitle,
        offerId: listingId,
        offerTitle,
        archivedBy,
        blockedBy,
        status: computeConversationStatus(normalizedParticipants, archivedBy, blockedBy),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      { merge: true },
    );

    return {
      ok: true,
      conversationId: doc.id,
      offerTitle,
    };
  }

  const conversationId = canonicalConversationId({ listingId, currentUserId, otherUserId });
  const participants = [currentUserId, otherUserId].sort();
  const convRef = convCol.doc(conversationId);

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(convRef);
    if (snap.exists) {
      const data = (snap.data() ?? {}) as Record<string, unknown>;
      const conversation = readConversationMirrorData(data, { conversationId: convRef.id });
      const normalizedParticipants = mergeConversationParticipants(conversation.participants, participants);

      const archivedBy = {
        ...conversation.archivedBy,
        [currentUserId]: false,
      };
      const blockedBy = conversation.blockedBy;

      transaction.set(
        convRef,
        buildConversationMirrorFields({
          ...conversation,
          participants: normalizedParticipants,
          participantNames: {
            ...conversation.participantNames,
            ...participantNames,
          },
          otherUserName,
          listingId,
          listingTitle: offerTitle,
          offerId: listingId,
          offerTitle,
          archivedBy,
          blockedBy,
          status: computeConversationStatus(normalizedParticipants, archivedBy, blockedBy),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
        { merge: true },
      );
      return;
    }

    transaction.set(
      convRef,
      buildConversationMirrorFields({
        participants,
        participantNames,
        otherUserName,
        listingId,
        listingTitle: offerTitle,
        offerId: listingId,
        offerTitle,
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
          [currentUserId]: 0,
          [otherUserId]: 0,
        },
      }),
    );
  });

  return {
    ok: true,
    conversationId,
    listingId,
    offerTitle,
  };
});

export const sendConversationMessage = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();
  const text = sanitizeMessageText(request.data?.text);
  const attachments = sanitizeConversationAttachments(request.data?.attachments, currentUserId, conversationId);
  const firstAttachment = attachments[0];
  const messageText = text || (firstAttachment
    ? (firstAttachment.type === "image" ? `Photo : ${firstAttachment.name}` : `Document : ${firstAttachment.name}`)
    : "");

  if (!conversationId || !messageText) {
    throw new HttpsError("invalid-argument", "conversationId and text or attachment are required");
  }

  if (messageText.length > 4000) {
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
      attachments.length === 0 &&
      latestSenderId === currentUserId &&
      latestText === messageText &&
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
    const conversation = readConversationMirrorData(data, { conversationId });
    const participants = conversation.participants;
    assertConversationParticipantAccess(participants, currentUserId);

    if (isConversationBlocked(data)) {
      throw new HttpsError("failed-precondition", "conversation is blocked");
    }

    const isFirstMessage = readConversationMessageCount(data) === 0;

    transaction.set(messageRef, {
      text: messageText,
      body: messageText,
      attachments,
      senderId: currentUserId,
      sender_id: currentUserId,
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
      unreadCount[participantId] = participantId == currentUserId
        ? 0
        : admin.firestore.FieldValue.increment(1);
    }

    transaction.update(
      convRef,
      buildConversationMirrorFields({
        ...conversation,
        participants,
        participantNames: {
          ...conversation.participantNames,
          [currentUserId]: senderName,
        },
        archivedBy,
        unreadCount,
        lastMessage: messageText,
        lastSenderId: currentUserId,
        lastSenderName: senderName,
        status: "open",
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      }),
    );
    participantsToRefresh = participants;
  });

  await Promise.all(participantsToRefresh.map((participantId) => refreshUnreadMessageCount(participantId)));

  return {
    ok: true,
    messageId: messageRef.id,
  };
});

export const markConversationRead = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      unreadCount: {
        ...conversation.unreadCount,
        [currentUserId]: 0,
      },
      lastReadAt: {
        ...conversation.lastReadAt,
        [currentUserId]: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  await refreshUnreadMessageCount(currentUserId);

  return { ok: true };
});

export const archiveConversation = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = {
    ...conversation.archivedBy,
    [currentUserId]: true,
  };
  const blockedBy = conversation.blockedBy;

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const unarchiveConversation = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = {
    ...conversation.archivedBy,
    [currentUserId]: false,
  };
  const blockedBy = conversation.blockedBy;

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const blockConversation = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = conversation.archivedBy;
  const blockedBy = {
    ...conversation.blockedBy,
    [currentUserId]: true,
  };

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const unblockConversation = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  if (!isConversationFlagEnabledForUser(data, "blockedBy", currentUserId)) {
    return { ok: true };
  }

  const archivedBy = readConversationFlagMap(data, "archivedBy");
  const blockedBy = {
    ...conversation.blockedBy,
    [currentUserId]: false,
  };

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const deleteConversation = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, participants } = await loadConversationForParticipant(conversationId, currentUserId);
  const notificationUserIds = await deleteNotificationsForConversation(conversationId);

  // Delete messages subcollection in batches
  const messagesRef = convRef.collection("messages");
  let batch = db.batch();
  let batchCount = 0;
  const BATCH_SIZE = 400;

  const messagesSnap = await messagesRef.limit(BATCH_SIZE).get();
  let remaining = messagesSnap.size;

  for (const doc of messagesSnap.docs) {
    batch.delete(doc.ref);
    batchCount++;
    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  // If there could be more messages beyond the first batch, continue
  if (remaining >= BATCH_SIZE) {
    let moreSnap = await messagesRef.limit(BATCH_SIZE).get();
    while (moreSnap.size > 0) {
      const deleteBatch = db.batch();
      for (const doc of moreSnap.docs) {
        deleteBatch.delete(doc.ref);
      }
      await deleteBatch.commit();
      moreSnap = await messagesRef.limit(BATCH_SIZE).get();
    }
  }

  // Delete the conversation document itself
  await convRef.delete();

  // Refresh unread counts for all participants
  await Promise.all(participants.map((pid) => refreshUnreadMessageCount(pid)));
  await Promise.all(Array.from(notificationUserIds, (userId) => refreshUnreadNotificationCount(userId)));

  return { ok: true };
});

export const deleteConversationMessage = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();
  const messageId = String(request.data?.messageId || "").trim();

  if (!conversationId || !messageId) {
    throw new HttpsError("invalid-argument", "conversationId and messageId are required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);

  const messageRef = convRef.collection("messages").doc(messageId);
  const messageSnap = await messageRef.get();

  if (!messageSnap.exists) {
    throw new HttpsError("not-found", "message not found");
  }

  const messageData = (messageSnap.data() ?? {}) as Record<string, unknown>;
  const senderId = String(messageData.senderId || messageData.sender_id || "").trim();
  const deletedCreatedAt = toDateOrNull(messageData.createdAt || messageData.created_at);

  if (senderId !== currentUserId) {
    throw new HttpsError("permission-denied", "you can only delete your own messages");
  }

  await messageRef.delete();

  const messagesRef = convRef.collection("messages");
  const [latestMessageSnap, messageCountSnap] = await Promise.all([
    messagesRef.orderBy("createdAt", "desc").limit(1).get(),
    messagesRef.count().get(),
  ]);
  const latestMessage = latestMessageSnap.docs[0]?.data() as Record<string, unknown> | undefined;
  const remainingMessageCount = messageCountSnap.data().count;
  const unreadCount = computeUnreadCountAfterMessageDeletion({
    participants,
    unreadCount: conversation.unreadCount,
    lastReadAt: conversation.lastReadAt,
    deletedSenderId: senderId,
    deletedCreatedAt,
  });
  const archivedBy = {
    ...conversation.archivedBy,
  };
  for (const participantId of participants) {
    archivedBy[participantId] = false;
  }

  await convRef.set(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      unreadCount,
      archivedBy,
      lastMessage: latestMessage
        ? sanitizeMessageText(latestMessage.text ?? latestMessage.body)
        : "",
      lastSenderId: latestMessage
        ? String(latestMessage.senderId || latestMessage.sender_id || "").trim()
        : "",
      lastSenderName: latestMessage
        ? normalizeParticipantName(latestMessage.senderName, latestMessage.sender_name)
        : "",
      lastMessageAt: latestMessage?.createdAt ?? latestMessage?.created_at,
      messageCount: remainingMessageCount,
      status: computeConversationStatus(participants, archivedBy, conversation.blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    { merge: true },
  );

  await Promise.all(participants.map((participantId) => refreshUnreadMessageCount(participantId)));

  return { ok: true };
});