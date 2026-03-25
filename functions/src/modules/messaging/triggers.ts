import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

// Cooldown de 15 min par conversation × destinataire pour éviter le spam
const MESSAGE_EMAIL_COOLDOWN_MS = 15 * 60 * 1000;

async function emitConversationMessageEvent({
  conversationId,
  messageId,
  recipientId,
  senderName,
  eventName,
}: {
  conversationId: string;
  messageId: string;
  recipientId: string;
  senderName: string;
  eventName: "message.created.new_thread" | "message.created.existing_thread";
}): Promise<void> {
  const canProceed = await canProceedRateLimited(
    "msg_email",
    `${conversationId}:${recipientId}`,
    1,
    MESSAGE_EMAIL_COOLDOWN_MS,
  );
  if (!canProceed) return;

  const recipientUser = await db.collection(COLLECTIONS.users).doc(recipientId).get();
  const recipientEmail = String(recipientUser.data()?.email || "").trim();
  if (!recipientEmail) return;

  const now = Date.now();
  const eventId = `evt_message_created_${messageId}_${recipientId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: eventName,
    source_collection: COLLECTIONS.conversations,
    source_id: conversationId,
    recipient_user_id: recipientId,
    dedupe_key: sha256(`message.created:${messageId}:${recipientId}:${eventName}`),
    occurred_at: now,
    payload: {
      recipient_email: recipientEmail,
      senderName,
      conversationUrl: `https://presto.app/messages/${conversationId}`,
    },
    status: "created",
  });
}

export const onMessageCreated = onDocumentCreated("conversation_messages/{messageId}", async (event) => {
  const message = event.data?.data();
  if (!message) return;

  const recipientId = String(message.recipient_id || "");
  if (!recipientId) return;

  const conversationId = String(message.conversation_id || event.params.messageId);

  const messageId = event.params.messageId;
  await emitConversationMessageEvent({
    conversationId,
    messageId,
    recipientId,
    senderName: String(message.sender_name || "Quelqu'un"),
    eventName: "message.created.existing_thread",
  });
});

export const onConversationSubMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const conversationId = String(event.params.conversationId || "");
    const messageId = String(event.params.messageId || "");
    const senderId = String(message.senderId || message.sender_id || "");
    const senderName = String(message.senderName || message.sender_name || "Quelqu'un");

    const conversationSnap = await db.collection(COLLECTIONS.conversations).doc(conversationId).get();
    const conversation = conversationSnap.data() ?? {};
    const participantSource = Array.isArray(conversation.participants)
      ? conversation.participants
      : Array.isArray(conversation.participant_ids)
        ? conversation.participant_ids
        : [];
    const participants = participantSource
      .map((value) => String(value || ""))
      .filter((value) => value.length > 0 && value !== senderId);

    const siblingMessages = await db
      .collection(COLLECTIONS.conversations)
      .doc(conversationId)
      .collection("messages")
      .limit(2)
      .get();
    const eventName = siblingMessages.size <= 1
      ? "message.created.new_thread"
      : "message.created.existing_thread";

    for (const recipientId of participants) {
      await emitConversationMessageEvent({
        conversationId,
        messageId,
        recipientId,
        senderName,
        eventName,
      });
    }
  },
);
