"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onConversationSubMessageCreated = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const env_1 = require("../../config/env");
const push_1 = require("../notifications/push");
const state_1 = require("./state");
const participants_1 = require("./participants");
const mirror_1 = require("./mirror");
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
    // isFirstMessage est positionné de manière transactionnelle par le callable.
    // Le trigger ne recalcule rien pour éviter les races entre messages concurrents.
    const isFirstMessage = message.isFirstMessage === true;
    const eventName = isFirstMessage
        ? "message.created.new_thread"
        : "message.created.existing_thread";
    const conversationSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId).get();
    const conversationData = (conversationSnap.data() ?? {});
    const conversation = (0, mirror_1.readConversationMirrorData)(conversationData, { conversationId });
    const normalizedParticipants = (0, participants_1.readConversationParticipants)(conversationData, { conversationId });
    const normalizedMessageText = String(message.text || message.body || "").trim();
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
                    : firebase_admin_1.default.firestore.FieldValue.increment(1);
            }
        }
        const participantNames = {
            ...conversation.participantNames,
        };
        if (senderId && senderName) {
            participantNames[senderId] = senderName;
        }
        await firestore_2.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId).set((0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants: normalizedParticipants,
            participantNames,
            lastMessage: normalizedMessageText || conversation.lastMessage,
            lastSenderId: senderId || conversation.lastSenderId,
            lastSenderName: senderName || conversation.lastSenderName,
            unreadCount,
            messageCount: isClientFirestoreFallback
                ? firebase_admin_1.default.firestore.FieldValue.increment(1)
                : (conversation.messageCount > 0 ? conversation.messageCount : 1),
            status: (0, state_1.computeConversationStatus)(normalizedParticipants, archivedBy, blockedBy),
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }), { merge: true });
    }
    const participants = normalizedParticipants
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
            (0, push_1.sendPushToUser)({
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
});
//# sourceMappingURL=triggers.js.map