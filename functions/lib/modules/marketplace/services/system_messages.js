"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendListingModerationSystemMessage = sendListingModerationSystemMessage;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const counters_1 = require("../../notifications/counters");
const mirror_1 = require("../../messaging/mirror");
const SYSTEM_SENDER_ID = "ilipresto_team";
const SYSTEM_SENDER_NAME = "L'équipe ilipresto";
function normalizeString(value) {
    return String(value ?? "").trim();
}
function systemConversationId(listingId, ownerId) {
    return `system_listing_${listingId.replaceAll("/", "_")}__${ownerId.replaceAll("/", "_")}`;
}
async function sendListingModerationSystemMessage({ ownerId, listingId, listingTitle, body, }) {
    const normalizedOwnerId = normalizeString(ownerId);
    const normalizedListingId = normalizeString(listingId);
    const normalizedBody = normalizeString(body);
    if (!normalizedOwnerId || !normalizedListingId || !normalizedBody) {
        return "";
    }
    const conversationId = systemConversationId(normalizedListingId, normalizedOwnerId);
    const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
    const messageRef = convRef.collection("messages").doc();
    await firestore_1.db.runTransaction(async (transaction) => {
        const convSnap = await transaction.get(convRef);
        const existing = convSnap.exists
            ? (0, mirror_1.readConversationMirrorData)((convSnap.data() ?? {}), { conversationId })
            : null;
        transaction.set(convRef, (0, mirror_1.buildConversationMirrorFields)({
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
                [normalizedOwnerId]: firebase_admin_1.default.firestore.FieldValue.increment(1),
                [SYSTEM_SENDER_ID]: 0,
            },
            createdAt: existing?.createdAt ?? firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessage: normalizedBody,
            lastSenderId: SYSTEM_SENDER_ID,
            lastSenderName: SYSTEM_SENDER_NAME,
            messageCount: convSnap.exists
                ? firebase_admin_1.default.firestore.FieldValue.increment(1)
                : 1,
        }), { merge: true });
        transaction.set(messageRef, {
            text: normalizedBody,
            body: normalizedBody,
            senderId: SYSTEM_SENDER_ID,
            sender_id: SYSTEM_SENDER_ID,
            senderName: SYSTEM_SENDER_NAME,
            sender_name: SYSTEM_SENDER_NAME,
            isFirstMessage: !convSnap.exists,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            created_at: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
    });
    await (0, counters_1.refreshUnreadMessageCount)(normalizedOwnerId);
    return conversationId;
}
//# sourceMappingURL=system_messages.js.map