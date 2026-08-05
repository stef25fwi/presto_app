import admin from "../../core/firebase_admin_compat";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";
import { APP_BASE_URL } from "../../config/env";
import { createInAppNotification, sendPushToUser } from "../notifications/push";
import { evaluateMessagingModeration, type MessagingAttachmentLike } from "./moderation";
import { computeConversationStatus } from "./state";
import { readConversationParticipants } from "./participants";
import {
  buildConversationMirrorFields,
  readConversationMirrorData,
} from "./mirror";

// Cooldown de 15 min par conversation × destinataire pour éviter le spam
const MESSAGE_EMAIL_COOLDOWN_MS = 15 * 60 * 1000;

function buildMessagePreview(value: unknown): string {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (text.length <= 120) return text;
  return `${text.slice(0, 117)}...`;
}

function parseMessageAttachments(value: unknown): MessagingAttachmentLike[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== "object") return [];
    const raw = entry as Record<string, unknown>;
    const type = String(raw.type || "").trim();
    if (type !== "image" && type !== "document" && type !== "audio") return [];
    const url = String(raw.url || "").trim();
    if (!url) return [];
    return [{
      type,
      name: String(raw.name || "").trim(),
      url,
      storagePath: String(raw.storagePath || "").trim(),
      mimeType: String(raw.mimeType || "").trim(),
      sizeBytes: Number(raw.sizeBytes || 0),
    } satisfies MessagingAttachmentLike];
  });
}

function moderatedMessagePlaceholder(status: string): string {
  if (status === "rejected") {
    return "Message retiré par la modération";
  }
  return "Message en cours de vérification";
}

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
  const eventId = `evt_message_created_${messageId}_${recipientId}_${eventName.replace(/\./g, "_")}`;

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
      conversationUrl: `${APP_BASE_URL}/messages/${conversationId}`,
    },
    status: "created",
  });
}

// Le trigger sur la sous-collection conversations/{id}/messages/{id} est la seule
// source valide : les messages sont toujours écrits via sendConversationMessage.
export const onConversationSubMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const messageSnapshot = event.data;
    const rawMessage = messageSnapshot?.data();
    if (!rawMessage) return;

    let message = rawMessage as Record<string, unknown>;

    const conversationId = String(event.params.conversationId || "");
    const messageId = String(event.params.messageId || "");
    const senderId = String(message.senderId || message.sender_id || "");
    const senderName = String(message.senderName || message.sender_name || "Quelqu'un");

    // isFirstMessage est positionné de manière transactionnelle par le callable.
    // Le trigger ne recalcule rien pour éviter les races entre messages concurrents.
    const isFirstMessage = message.isFirstMessage === true;
    const eventName = isFirstMessage
      ? "message.created.new_thread"
      : "message.created.existing_thread";

    const moderation = (message.moderation ?? {}) as Record<string, unknown>;
    const moderationMode = String(moderation.mode || "hybrid").trim().toLowerCase();
    const moderationStatus = String(moderation.status || "").trim().toLowerCase();
    if (moderationStatus === "pending") {
      const evaluated = await evaluateMessagingModeration({
        mode: moderationMode === "visible_then_retract"
          ? "visible_then_retract"
          : moderationMode === "hidden_until_validated"
            ? "hidden_until_validated"
            : "hybrid",
        text: String(message.text || message.body || "").trim(),
        attachments: parseMessageAttachments(message.attachments),
      });
      const nextModeration = {
        mode: evaluated.mode,
        status: evaluated.status,
        visibility: evaluated.visibility,
        reason: evaluated.moderationReason,
        userMessage: evaluated.userMessage,
        autoFlags: evaluated.autoFlags,
        riskScore: evaluated.riskScore,
        textScanStatus: evaluated.textScanStatus,
        imageScanStatus: evaluated.imageScanStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await messageSnapshot?.ref.set({
        moderation: nextModeration,
      }, { merge: true });
      message = {
        ...message,
        moderation: nextModeration,
      };
    }

    const conversationSnap = await db.collection(COLLECTIONS.conversations).doc(conversationId).get();
    const conversationData = (conversationSnap.data() ?? {}) as Record<string, unknown>;
    const conversation = readConversationMirrorData(conversationData, { conversationId });
    const normalizedParticipants = readConversationParticipants(conversationData, { conversationId });
    const resolvedModeration = (message.moderation ?? {}) as Record<string, unknown>;
    const resolvedModerationStatus = String(resolvedModeration.status || "").trim().toLowerCase();
    const resolvedModerationVisibility = String(resolvedModeration.visibility || "visible").trim().toLowerCase();
    const shouldHideContent = resolvedModerationStatus === "rejected" ||
      resolvedModerationStatus === "manual_review" ||
      (resolvedModerationStatus === "pending" && resolvedModerationVisibility === "hidden");
    const normalizedMessageText = shouldHideContent
      ? moderatedMessagePlaceholder(resolvedModerationStatus)
      : String(message.text || message.body || "").trim();
    const shouldNotifyParticipants = !shouldHideContent;
    const messagePreview = buildMessagePreview(normalizedMessageText);
    const isClientFirestoreFallback = message.createdVia === "client_firestore_fallback";

    if (normalizedParticipants.length > 0) {
      const archivedBy = conversation.archivedBy;
      const blockedBy = conversation.blockedBy;
      const unreadCount = {
        ...conversation.unreadCount,
      };
      if (isClientFirestoreFallback) {
        for (const participantId of normalizedParticipants) {
          unreadCount[participantId] = participantId === senderId
            ? 0
            : admin.firestore.FieldValue.increment(1);
        }
      }
      const participantNames = {
        ...conversation.participantNames,
      };
      if (senderId && senderName) {
        participantNames[senderId] = senderName;
      }

      await db.collection(COLLECTIONS.conversations).doc(conversationId).set(
        buildConversationMirrorFields({
          ...conversation,
          participants: normalizedParticipants,
          participantNames,
          lastMessage: normalizedMessageText || conversation.lastMessage,
          lastSenderId: senderId || conversation.lastSenderId,
          lastSenderName: senderName || conversation.lastSenderName,
          unreadCount,
          messageCount: isClientFirestoreFallback
            ? admin.firestore.FieldValue.increment(1)
            : (conversation.messageCount > 0 ? conversation.messageCount : 1),
          status: computeConversationStatus(normalizedParticipants, archivedBy, blockedBy),
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
        { merge: true },
      );
    }

    const participants = normalizedParticipants
      .filter((value) => value.length > 0 && value !== senderId);
    const offerTitle = String(conversation.offerTitle || "Annonce IliPresto").trim();
    const offerId = String(conversation.offerId || "").trim();
    const routeName = `/messages/${encodeURIComponent(conversationId)}`;

    if (!shouldNotifyParticipants) {
      return;
    }

    for (const recipientId of participants) {
      const notificationId = `notif_message_${messageId}_${recipientId}`;
      await Promise.all([
        emitConversationMessageEvent({
          conversationId,
          messageId,
          recipientId,
          senderName,
          eventName,
        }),
        createInAppNotification({
          notificationId,
          userId: recipientId,
          title: "Nouveau message reçu !",
          message: "Une réponse t'attend sur iliprestō. Consulte-la maintenant.",
          type: "new_message",
          routeName,
          conversationId,
          offerId: offerId || undefined,
          data: {
            offerTitle,
          },
        }),
        sendPushToUser({
          userId: recipientId,
          topic: "messaging",
          title: "Nouveau message reçu !",
          body: "Une réponse t'attend sur iliprestō. Consulte-la maintenant.",
          routeName,
          channelId: "ilipresto_messages",
          collapseKey: `conversation_${conversationId}`,
          data: {
            type: "new_message",
            conversationId,
            offerId,
            notificationId,
          },
        }),
      ]);
    }
  },
);
