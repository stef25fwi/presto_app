"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onMessageCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
// Cooldown de 15 min par conversation × destinataire pour éviter le spam
const MESSAGE_EMAIL_COOLDOWN_MS = 15 * 60 * 1000;
exports.onMessageCreated = (0, firestore_1.onDocumentCreated)("conversation_messages/{messageId}", async (event) => {
    const message = event.data?.data();
    if (!message)
        return;
    const recipientId = String(message.recipient_id || "");
    if (!recipientId)
        return;
    const conversationId = String(message.conversation_id || event.params.messageId);
    // Coalescing : un seul email par conversation × destinataire toutes les 15 min
    const canProceed = await (0, rate_limit_1.canProceedRateLimited)("msg_email", `${conversationId}:${recipientId}`, 1, MESSAGE_EMAIL_COOLDOWN_MS);
    if (!canProceed)
        return;
    const recipientUser = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(recipientId).get();
    const recipientEmail = String(recipientUser.data()?.email || "").trim();
    if (!recipientEmail)
        return;
    const messageId = event.params.messageId;
    const now = Date.now();
    const eventId = `evt_message_created_${messageId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "message.created.existing_thread",
        source_collection: constants_1.COLLECTIONS.conversationMessages,
        source_id: messageId,
        recipient_user_id: recipientId,
        dedupe_key: (0, hash_1.sha256)(`message.created:${messageId}:${recipientId}`),
        occurred_at: now,
        payload: {
            recipient_email: recipientEmail,
            senderName: String(message.sender_name || "Quelqu'un"),
            conversationUrl: `https://presto.app/messages/${conversationId}`,
        },
        status: "created",
    });
});
//# sourceMappingURL=triggers.js.map