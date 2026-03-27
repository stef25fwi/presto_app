"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onConversationSubMessageCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const env_1 = require("../../config/env");
const push_1 = require("../notifications/push");
// Cooldown de 15 min par conversation × destinataire pour éviter le spam
const MESSAGE_EMAIL_COOLDOWN_MS = 15 * 60 * 1000;
function buildMessagePreview(value) {
    const text = String(value || "").replace(/\s+/g, " ").trim();
    if (text.length <= 120)
        return text;
    return `${text.slice(0, 117)}...`;
}
async function emitConversationMessageEvent({ conversationId, messageId, recipientId, senderName, eventName, }) {
    const canProceed = await (0, rate_limit_1.canProceedRateLimited)("msg_email", `${conversationId}:${recipientId}`, 1, MESSAGE_EMAIL_COOLDOWN_MS);
    if (!canProceed)
        return;
    const recipientUser = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(recipientId).get();
    const recipientEmail = String(recipientUser.data()?.email || "").trim();
    if (!recipientEmail)
        return;
    const now = Date.now();
    const eventId = `evt_message_created_${messageId}_${recipientId}_${eventName.replace(/\./g, "_")}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: constants_1.COLLECTIONS.conversations,
        source_id: conversationId,
        recipient_user_id: recipientId,
        dedupe_key: (0, hash_1.sha256)(`message.created:${messageId}:${recipientId}:${eventName}`),
        occurred_at: now,
        payload: {
            recipient_email: recipientEmail,
            senderName,
            conversationUrl: `${env_1.APP_BASE_URL}/messages/${conversationId}`,
        },
        status: "created",
    });
}
// Le trigger sur la sous-collection conversations/{id}/messages/{id} est la seule
// source valide : les messages sont toujours écrits via sendConversationMessage.
exports.onConversationSubMessageCreated = (0, firestore_1.onDocumentCreated)("conversations/{conversationId}/messages/{messageId}", async (event) => {
    const message = event.data?.data();
    if (!message)
        return;
    const conversationId = String(event.params.conversationId || "");
    const messageId = String(event.params.messageId || "");
    const senderId = String(message.senderId || message.sender_id || "");
    const senderName = String(message.senderName || message.sender_name || "Quelqu'un");
    const messagePreview = buildMessagePreview(message.text);
    // isFirstMessage est positionné par le callable sendConversationMessage.
    // Cela évite la race condition lié au comptage de messages frères.
    const isFirstMessage = message.isFirstMessage === true;
    const eventName = isFirstMessage
        ? "message.created.new_thread"
        : "message.created.existing_thread";
    const conversationSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId).get();
    const conversation = conversationSnap.data() ?? {};
    const participantSource = Array.isArray(conversation.participants)
        ? conversation.participants
        : Array.isArray(conversation.participant_ids)
            ? conversation.participant_ids
            : [];
    const participants = participantSource
        .map((value) => String(value || ""))
        .filter((value) => value.length > 0 && value !== senderId);
    const offerTitle = String(conversation.offerTitle || "Annonce IliPresto").trim();
    const offerId = String(conversation.offerId || "").trim();
    const routeName = `/messages/${encodeURIComponent(conversationId)}`;
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
            (0, push_1.createInAppNotification)({
                notificationId,
                userId: recipientId,
                title: senderName,
                message: messagePreview || `Nouveau message dans ${offerTitle}`,
                type: "new_message",
                routeName,
                conversationId,
                offerId: offerId || undefined,
                data: {
                    offerTitle,
                },
            }),
            (0, push_1.sendPushToUser)({
                userId: recipientId,
                topic: "messaging",
                title: senderName,
                body: messagePreview || `Nouveau message dans ${offerTitle}`,
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
});
//# sourceMappingURL=triggers.js.map