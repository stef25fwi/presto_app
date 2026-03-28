"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendChatMessage = exports.createChatThreadFromListing = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const rate_limit_1 = require("../../../core/rate_limit");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const counters_1 = require("../../notifications/counters");
const participants_1 = require("../../messaging/participants");
const mirror_1 = require("../../messaging/mirror");
const state_1 = require("../../messaging/state");
const analytics_1 = require("../services/analytics");
const errors_1 = require("../services/errors");
const recaptcha_1 = require("../services/recaptcha");
const listings_1 = require("../validators/listings");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function normalizeString(value) {
    return String(value ?? "").trim();
}
function canonicalConversationId(listingId, participants) {
    return `offer_${listingId.replaceAll("/", "_")}__${participants
        .map((value) => value.replaceAll("/", "_"))
        .sort()
        .join("__")}`;
}
function readListingOwnerId(listingData) {
    return normalizeString(listingData.ownerId) ||
        normalizeString(listingData.userId) ||
        normalizeString(listingData.uid);
}
function normalizeDisplayName(...values) {
    for (const value of values) {
        const normalized = normalizeString(value);
        if (normalized)
            return normalized;
    }
    return "Utilisateur";
}
async function findExistingConversationIdForListing(listingId, participantA, participantB) {
    const snapshots = await Promise.all(participants_1.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.flatMap((field) => [
        firestore_1.db.collection(constants_1.COLLECTIONS.conversations)
            .where(field, "array-contains", participantA)
            .where("offerId", "==", listingId)
            .limit(20)
            .get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.conversations)
            .where(field, "array-contains", participantA)
            .where("offer_id", "==", listingId)
            .limit(20)
            .get(),
    ]));
    const deduped = new Map();
    for (const snapshot of snapshots) {
        for (const doc of snapshot.docs) {
            deduped.set(doc.id, doc);
        }
    }
    for (const doc of deduped.values()) {
        const participants = (0, participants_1.readConversationParticipants)((doc.data() ?? {}));
        if (participants.includes(participantA) && participants.includes(participantB)) {
            return doc.id;
        }
    }
    return null;
}
async function appendConversationMessage({ conversationId, senderId, senderName, body, }) {
    const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
    const messageRef = convRef.collection("messages").doc();
    let participantsToRefresh = [];
    let listingId = "";
    await firestore_1.db.runTransaction(async (transaction) => {
        const convSnap = await transaction.get(convRef);
        if (!convSnap.exists) {
            throw new https_1.HttpsError("not-found", "Conversation not found");
        }
        const data = (convSnap.data() ?? {});
        const participants = (0, participants_1.readConversationParticipants)(data);
        if (!participants.includes(senderId)) {
            throw new https_1.HttpsError("permission-denied", "You are not a participant of this conversation");
        }
        if ((0, state_1.isConversationBlocked)(data)) {
            throw new https_1.HttpsError("failed-precondition", "Conversation is blocked");
        }
        const conversation = (0, mirror_1.readConversationMirrorData)(data);
        const isFirstMessage = Number(conversation.messageCount || 0) <= 0;
        listingId = normalizeString(conversation.offerId);
        transaction.set(messageRef, {
            text: body,
            body,
            senderId,
            sender_id: senderId,
            senderName,
            sender_name: senderName,
            isFirstMessage,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            created_at: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        const archivedBy = {
            ...conversation.archivedBy,
        };
        const unreadCount = {
            ...conversation.unreadCount,
        };
        for (const participantId of participants) {
            archivedBy[participantId] = false;
            unreadCount[participantId] = participantId === senderId
                ? 0
                : firebase_admin_1.default.firestore.FieldValue.increment(1);
        }
        transaction.set(convRef, (0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants,
            participantNames: {
                ...conversation.participantNames,
                [senderId]: senderName,
            },
            archivedBy,
            unreadCount,
            lastMessage: body,
            lastSenderId: senderId,
            lastSenderName: senderName,
            status: "open",
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            messageCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
        }), { merge: true });
        participantsToRefresh = participants;
    });
    await Promise.all(participantsToRefresh.map((participantId) => (0, counters_1.refreshUnreadMessageCount)(participantId)));
    return {
        messageId: messageRef.id,
        listingId,
        participants: participantsToRefresh,
    };
}
exports.createChatThreadFromListing = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const senderId = requireAuthUid(request);
    const listingId = normalizeString(request.data?.listingId);
    const initialMessage = normalizeString(request.data?.message);
    const recaptchaToken = normalizeString(request.data?.recaptchaToken);
    if (!listingId) {
        throw new https_1.HttpsError("invalid-argument", "listingId is required");
    }
    if (!initialMessage) {
        throw new https_1.HttpsError("invalid-argument", "message is required");
    }
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("chat_thread_create", senderId, 10, 60 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many chat threads created recently");
    }
    const recaptcha = await (0, recaptcha_1.verifyRecaptchaAssessment)({
        token: recaptchaToken,
        expectedAction: "message_create",
        userId: senderId,
    });
    if (!recaptcha.allowed) {
        throw new https_1.HttpsError("permission-denied", "reCAPTCHA rejected the first message");
    }
    try {
        const body = (0, listings_1.validateChatMessageBody)(initialMessage);
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
        const listingSnap = await listingRef.get();
        if (!listingSnap.exists) {
            throw new https_1.HttpsError("not-found", "Listing not found");
        }
        const listingData = (listingSnap.data() ?? {});
        const ownerId = readListingOwnerId(listingData);
        if (!ownerId || ownerId === senderId) {
            throw new https_1.HttpsError("failed-precondition", "Cannot open a thread on your own listing");
        }
        const existingConversationId = await findExistingConversationIdForListing(listingId, senderId, ownerId);
        const conversationId = existingConversationId ?? canonicalConversationId(listingId, [senderId, ownerId]);
        if (!existingConversationId) {
            const [ownerUserSnap, senderUserSnap] = await Promise.all([
                firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get(),
                firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(senderId).get(),
            ]);
            const ownerData = (ownerUserSnap.data() ?? {});
            const senderData = (senderUserSnap.data() ?? {});
            await firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId).set((0, mirror_1.buildConversationMirrorFields)({
                participants: [senderId, ownerId].sort(),
                participantNames: {
                    [ownerId]: normalizeDisplayName(ownerData.displayName, ownerData.display_name, ownerData.name),
                    [senderId]: normalizeDisplayName(senderData.displayName, senderData.display_name, senderData.name),
                },
                otherUserName: normalizeDisplayName(ownerData.displayName, ownerData.display_name, ownerData.name),
                offerId: listingId,
                offerTitle: normalizeString(listingData.title) || "Annonce IliPresto",
                status: "open",
                archivedBy: {},
                blockedBy: {},
                lastReadAt: {},
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                lastMessage: "",
                lastSenderId: "",
                lastSenderName: "",
                messageCount: 0,
                unreadCount: {
                    [senderId]: 0,
                    [ownerId]: 0,
                },
            }), { merge: true });
        }
        const senderName = normalizeDisplayName(request.data?.senderName, request.auth?.token?.name, request.auth?.token?.email);
        const { messageId } = await appendConversationMessage({
            conversationId,
            senderId,
            senderName,
            body,
        });
        await (0, analytics_1.trackProductEventBackend)({
            eventName: "listing_message_started",
            userId: senderId,
            listingId,
            threadId: conversationId,
        });
        return {
            ok: true,
            threadId: conversationId,
            messageId,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to create chat thread");
    }
});
exports.sendChatMessage = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const senderId = requireAuthUid(request);
    const threadId = normalizeString(request.data?.threadId);
    if (!threadId) {
        throw new https_1.HttpsError("invalid-argument", "threadId is required");
    }
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("chat_message_send", senderId, 30, 5 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many messages sent recently");
    }
    try {
        const body = (0, listings_1.validateChatMessageBody)(request.data?.message);
        const senderName = normalizeDisplayName(request.data?.senderName, request.auth?.token?.name, request.auth?.token?.email);
        const { messageId } = await appendConversationMessage({
            conversationId: threadId,
            senderId,
            senderName,
            body,
        });
        logger_1.logger.info("marketplace_chat_message_sent", {
            threadId,
            senderId,
            messageId,
        });
        return {
            ok: true,
            messageId,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to send chat message");
    }
});
//# sourceMappingURL=chat.js.map