import admin from "firebase-admin";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { refreshUnreadMessageCount } from "../../notifications/counters";
import { buildConversationMirrorFields, readConversationMirrorData } from "../../messaging/mirror";

const SYSTEM_SENDER_ID = "ilipresto_team";
const SYSTEM_SENDER_NAME = "L'équipe ilipresto";

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function systemConversationId(listingId: string, ownerId: string): string {
  return `system_listing_${listingId.replaceAll("/", "_")}__${ownerId.replaceAll("/", "_")}`;
}

export async function sendListingModerationSystemMessage({
  ownerId,
  listingId,
  listingTitle,
  body,
}: {
  ownerId: string;
  listingId: string;
  listingTitle?: string;
  body: string;
}): Promise<string> {
  const normalizedOwnerId = normalizeString(ownerId);
  const normalizedListingId = normalizeString(listingId);
  const normalizedBody = normalizeString(body);
  if (!normalizedOwnerId || !normalizedListingId || !normalizedBody) {
    return "";
  }

  const conversationId = systemConversationId(normalizedListingId, normalizedOwnerId);
  const convRef = db.collection(COLLECTIONS.conversations).doc(conversationId);
  const messageRef = convRef.collection("messages").doc();

  await db.runTransaction(async (transaction) => {
    const convSnap = await transaction.get(convRef);
    const existing = convSnap.exists
      ? readConversationMirrorData((convSnap.data() ?? {}) as Record<string, unknown>, { conversationId })
      : null;

    transaction.set(
      convRef,
      buildConversationMirrorFields({
        participants: [normalizedOwnerId, SYSTEM_SENDER_ID].sort(),
        participantNames: {
          [normalizedOwnerId]: existing?.participantNames[normalizedOwnerId] ?? "Vous",
          [SYSTEM_SENDER_ID]: SYSTEM_SENDER_NAME,
        },
        otherUserName: SYSTEM_SENDER_NAME,
        listingId: normalizedListingId,
        listingTitle: normalizeString(listingTitle) || "Modération ilipresto",
        offerId: normalizedListingId,
        offerTitle: normalizeString(listingTitle) || "Modération ilipresto",
        status: "open",
        archivedBy: existing?.archivedBy ?? {},
        blockedBy: existing?.blockedBy ?? {},
        lastReadAt: existing?.lastReadAt ?? {},
        unreadCount: {
          ...(existing?.unreadCount ?? {}),
          [normalizedOwnerId]: admin.firestore.FieldValue.increment(1),
          [SYSTEM_SENDER_ID]: 0,
        },
        createdAt: existing?.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: normalizedBody,
        lastSenderId: SYSTEM_SENDER_ID,
        lastSenderName: SYSTEM_SENDER_NAME,
        messageCount: convSnap.exists
          ? admin.firestore.FieldValue.increment(1)
          : 1,
      }),
      { merge: true },
    );

    transaction.set(messageRef, {
      text: normalizedBody,
      body: normalizedBody,
      senderId: SYSTEM_SENDER_ID,
      sender_id: SYSTEM_SENDER_ID,
      senderName: SYSTEM_SENDER_NAME,
      sender_name: SYSTEM_SENDER_NAME,
      isFirstMessage: !convSnap.exists,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await refreshUnreadMessageCount(normalizedOwnerId);
  return conversationId;
}