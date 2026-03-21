import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

// Cooldown de 15 min par conversation × destinataire pour éviter le spam
const MESSAGE_EMAIL_COOLDOWN_MS = 15 * 60 * 1000;

export const onMessageCreated = onDocumentCreated("conversation_messages/{messageId}", async (event) => {
  const message = event.data?.data();
  if (!message) return;

  const recipientId = String(message.recipient_id || "");
  if (!recipientId) return;

  const conversationId = String(message.conversation_id || event.params.messageId);

  // Coalescing : un seul email par conversation × destinataire toutes les 15 min
  const canProceed = await canProceedRateLimited("msg_email", `${conversationId}:${recipientId}`, 1, MESSAGE_EMAIL_COOLDOWN_MS);
  if (!canProceed) return;

  const recipientUser = await db.collection(COLLECTIONS.users).doc(recipientId).get();
  const recipientEmail = String(recipientUser.data()?.email || "").trim();
  if (!recipientEmail) return;

  const messageId = event.params.messageId;
  const now = Date.now();
  const eventId = `evt_message_created_${messageId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "message.created.existing_thread",
    source_collection: COLLECTIONS.conversationMessages,
    source_id: messageId,
    recipient_user_id: recipientId,
    dedupe_key: sha256(`message.created:${messageId}:${recipientId}`),
    occurred_at: now,
    payload: {
      recipient_email: recipientEmail,
      senderName: String(message.sender_name || "Quelqu'un"),
      conversationUrl: `https://presto.app/messages/${conversationId}`,
    },
    status: "created",
  });
});
