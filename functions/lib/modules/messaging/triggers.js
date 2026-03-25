"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onConversationSubMessageCreated = exports.onMessageCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
// Cooldown de 15 min par conversation × destinataire pour éviter le spam
const MESSAGE_EMAIL_COOLDOWN_MS = 15 * 60 * 1000;
async function emitConversationMessageEvent({ conversationId, messageId, recipientId, senderName, eventName, }) {
    const canProceed = await (0, rate_limit_1.canProceedRateLimited)("msg_email", `${conversationId}:${recipientId}`, 1, MESSAGE_EMAIL_COOLDOWN_MS);
    if (!canProceed)
        return;
    const recipientUser = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(recipientId).get();
    const recipientEmail = String(recipientUser.data()?.email || "").trim();
    if (!recipientEmail)
        return;
    const now = Date.now();
    const eventId = `evt_message_created_${messageId}_${recipientId}_${now}`;
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
            conversationUrl: `https://presto.app/messages/${conversationId}`,
        },
        status: "created",
    });
}
exports.onMessageCreated = (0, firestore_1.onDocumentCreated)("conversation_messages/{messageId}", async (event) => {
    const message = event.data?.data();
    if (!message)
        return;
    const recipientId = String(message.recipient_id || "");
    if (!recipientId)
        return;
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
exports.onConversationSubMessageCreated = (0, firestore_1.onDocumentCreated)("conversations/{conversationId}/messages/{messageId}", async (event) => {
    const message = event.data?.data();
    if (!message)
        return;
    const conversationId = String(event.params.conversationId || "");
    const messageId = String(event.params.messageId || "");
    const senderId = String(message.senderId || message.sender_id || "");
    const senderName = String(message.senderName || message.sender_name || "Quelqu'un");
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
    const siblingMessages = await firestore_2.db
        .collection(constants_1.COLLECTIONS.conversations)
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
});
//# sourceMappingURL=triggers.js.map