"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteConversationMessage = exports.deleteConversation = exports.unblockConversation = exports.blockConversation = exports.unarchiveConversation = exports.archiveConversation = exports.markConversationRead = exports.sendConversationMessage = exports.ensureOfferConversation = void 0;
exports.readConversationMessageCount = readConversationMessageCount;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const counters_1 = require("../notifications/counters");
const state_1 = require("./state");
const participants_1 = require("./participants");
const MESSAGE_SEND_WINDOW_MS = 10 * 1000;
const MESSAGE_SEND_LIMIT = 6;
const DUPLICATE_MESSAGE_WINDOW_MS = 15 * 1000;
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    return uid;
}
function sanitizeConversationPart(value) {
    return value.replaceAll("/", "_").trim();
}
function canonicalConversationId({ offerId, currentUserId, otherUserId, }) {
    const participants = [sanitizeConversationPart(currentUserId), sanitizeConversationPart(otherUserId)].sort();
    return `offer_${sanitizeConversationPart(offerId)}__${participants.join("__")}`;
}
function normalizeParticipantName(...values) {
    for (const value of values) {
        const normalized = String(value || "").trim();
        if (normalized)
            return normalized;
    }
    return "Utilisateur";
}
function readOfferOwnerId(data) {
    for (const field of ["ownerId", "userId", "uid"]) {
        const value = String(data[field] || "").trim();
        if (value)
            return value;
    }
    return "";
}
function readUserDisplayName(data, ...fallbacks) {
    return normalizeParticipantName(data?.displayName, data?.display_name, data?.name, ...fallbacks);
}
function sanitizeMessageText(value) {
    return String(value ?? "")
        .split("\n")
        .map((line) => line.replace(/\s+$/g, ""))
        .join("\n")
        .trim();
}
function readConversationMessageCount(data) {
    const rawCount = data.messageCount;
    if (typeof rawCount === "number" && Number.isFinite(rawCount) && rawCount > 0) {
        return Math.floor(rawCount);
    }
    return String(data.lastMessage || "").trim() !== "" ? 1 : 0;
}
function toDateOrNull(value) {
    if (value instanceof firebase_admin_1.default.firestore.Timestamp)
        return value.toDate();
    if (value instanceof Date)
        return value;
    if (typeof value === "number" && Number.isFinite(value))
        return new Date(value);
    return null;
}
async function loadConversationForParticipant(conversationId, currentUserId) {
    const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
        throw new https_1.HttpsError("not-found", "conversation not found");
    }
    const data = (convSnap.data() ?? {});
    const participants = (0, participants_1.readConversationParticipants)(data);
    if (!participants.includes(currentUserId)) {
        throw new https_1.HttpsError("permission-denied", "not allowed to access this conversation");
    }
    return { convRef, data, participants };
}
exports.ensureOfferConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const offerId = String(request.data?.offerId || "").trim();
    const otherUserId = String(request.data?.otherUserId || "").trim();
    if (!offerId || !otherUserId) {
        throw new https_1.HttpsError("invalid-argument", "offerId and otherUserId are required");
    }
    if (currentUserId == otherUserId) {
        throw new https_1.HttpsError("failed-precondition", "cannot create a conversation with yourself");
    }
    const offerSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.offers).doc(offerId).get();
    if (!offerSnap.exists) {
        throw new https_1.HttpsError("not-found", "offer not found");
    }
    const offerData = (offerSnap.data() ?? {});
    const offerOwnerId = readOfferOwnerId(offerData);
    if (!offerOwnerId) {
        throw new https_1.HttpsError("failed-precondition", "offer owner is missing");
    }
    if (offerOwnerId != otherUserId) {
        throw new https_1.HttpsError("permission-denied", "conversation target does not match offer owner");
    }
    const offerTitle = String(offerData.title || request.data?.offerTitle || "").trim();
    if (!offerTitle) {
        throw new https_1.HttpsError("failed-precondition", "offer title is missing");
    }
    const [currentUserSnap, otherUserSnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(currentUserId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(otherUserId).get(),
    ]);
    const currentUserName = readUserDisplayName(currentUserSnap.data(), request.auth?.token?.name, request.auth?.token?.email, currentUserId);
    const otherUserName = readUserDisplayName(otherUserSnap.data(), offerData.advertiserName, otherUserId);
    const participantNames = {
        [currentUserId]: currentUserName,
        [otherUserId]: otherUserName,
    };
    const convCol = firestore_1.db.collection(constants_1.COLLECTIONS.conversations);
    const [existingCurrent, existingLegacy] = await Promise.all([
        convCol
            .where("participants", "array-contains", currentUserId)
            .where("offerId", "==", offerId)
            .limit(20)
            .get(),
        convCol
            .where("participant_ids", "array-contains", currentUserId)
            .where("offerId", "==", offerId)
            .limit(20)
            .get(),
    ]);
    const existingDocs = new Map();
    for (const doc of [...existingCurrent.docs, ...existingLegacy.docs]) {
        existingDocs.set(doc.id, doc);
    }
    for (const doc of existingDocs.values()) {
        const docData = doc.data();
        const participants = (0, participants_1.readConversationParticipants)(docData);
        if (!participants.includes(otherUserId))
            continue;
        if ((0, state_1.isConversationBlocked)(docData)) {
            throw new https_1.HttpsError("failed-precondition", "conversation is blocked");
        }
        const archivedBy = {
            ...(0, state_1.readConversationFlagMap)(docData, "archivedBy"),
            [currentUserId]: false,
        };
        const blockedBy = (0, state_1.readConversationFlagMap)(docData, "blockedBy");
        await doc.ref.set({
            ...(0, participants_1.buildConversationParticipantFields)(participants),
            participantNames,
            otherUserName,
            [`archivedBy.${currentUserId}`]: false,
            status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return {
            ok: true,
            conversationId: doc.id,
            offerTitle,
        };
    }
    const conversationId = canonicalConversationId({ offerId, currentUserId, otherUserId });
    const participants = [currentUserId, otherUserId].sort();
    const convRef = convCol.doc(conversationId);
    await firestore_1.db.runTransaction(async (transaction) => {
        const snap = await transaction.get(convRef);
        if (snap.exists) {
            const data = (snap.data() ?? {});
            const existingParticipants = (0, participants_1.readConversationParticipants)(data);
            const normalizedParticipants = existingParticipants.length > 0
                ? existingParticipants
                : participants;
            transaction.set(convRef, {
                ...(0, participants_1.buildConversationParticipantFields)(normalizedParticipants),
                participantNames,
                otherUserName,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            return;
        }
        transaction.set(convRef, {
            offerId,
            offerTitle,
            ...(0, participants_1.buildConversationParticipantFields)(participants),
            participantNames,
            otherUserName,
            status: "open",
            archivedBy: {},
            blockedBy: {},
            lastReadAt: {},
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessage: "",
            messageCount: 0,
            unreadCount: {
                [currentUserId]: 0,
                [otherUserId]: 0,
            },
        });
    });
    return {
        ok: true,
        conversationId,
        offerTitle,
    };
});
exports.sendConversationMessage = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const text = sanitizeMessageText(request.data?.text);
    if (!conversationId || !text) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and text are required");
    }
    if (text.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "message is too long");
    }
    const canSend = await (0, rate_limit_1.canProceedRateLimited)("msg_send", `${currentUserId}:${conversationId}`, MESSAGE_SEND_LIMIT, MESSAGE_SEND_WINDOW_MS);
    if (!canSend) {
        throw new https_1.HttpsError("resource-exhausted", "too many messages sent too quickly");
    }
    const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);
    const latestMessageSnap = await convRef
        .collection("messages")
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();
    const latestMessageDoc = latestMessageSnap.docs[0];
    if (latestMessageDoc) {
        const latestData = latestMessageDoc.data();
        const latestSenderId = String(latestData.senderId || "").trim();
        const latestText = sanitizeMessageText(latestData.text);
        const latestCreatedAt = toDateOrNull(latestData.createdAt);
        if (latestSenderId === currentUserId &&
            latestText === text &&
            latestCreatedAt != null &&
            Date.now() - latestCreatedAt.getTime() <= DUPLICATE_MESSAGE_WINDOW_MS) {
            return {
                ok: true,
                deduplicated: true,
                messageId: latestMessageDoc.id,
            };
        }
    }
    const senderUserSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(currentUserId).get();
    const senderName = readUserDisplayName(senderUserSnap.data(), request.auth?.token?.name, request.auth?.token?.email, currentUserId);
    const messageRef = convRef.collection("messages").doc();
    let participantsToRefresh = [];
    await firestore_1.db.runTransaction(async (transaction) => {
        const convSnap = await transaction.get(convRef);
        if (!convSnap.exists) {
            throw new https_1.HttpsError("not-found", "conversation not found");
        }
        const data = (convSnap.data() ?? {});
        const participants = (0, participants_1.readConversationParticipants)(data);
        if (!participants.includes(currentUserId)) {
            throw new https_1.HttpsError("permission-denied", "not allowed to access this conversation");
        }
        if ((0, state_1.isConversationBlocked)(data)) {
            throw new https_1.HttpsError("failed-precondition", "conversation is blocked");
        }
        const isFirstMessage = readConversationMessageCount(data) === 0;
        transaction.set(messageRef, {
            text,
            senderId: currentUserId,
            senderName,
            isFirstMessage,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        const conversationUpdate = {
            ...(0, participants_1.buildConversationParticipantFields)(participants),
            lastMessage: text,
            lastSenderId: currentUserId,
            lastSenderName: senderName,
            status: "open",
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            messageCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
            [`participantNames.${currentUserId}`]: senderName,
        };
        for (const participantId of participants) {
            conversationUpdate[`archivedBy.${participantId}`] = false;
            conversationUpdate[`unreadCount.${participantId}`] = participantId == currentUserId
                ? 0
                : firebase_admin_1.default.firestore.FieldValue.increment(1);
        }
        transaction.update(convRef, conversationUpdate);
        participantsToRefresh = participants;
    });
    await Promise.all(participantsToRefresh.map((participantId) => (0, counters_1.refreshUnreadMessageCount)(participantId)));
    return {
        ok: true,
        messageId: messageRef.id,
    };
});
exports.markConversationRead = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);
    await convRef.update({
        [`unreadCount.${currentUserId}`]: 0,
        [`lastReadAt.${currentUserId}`]: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    await (0, counters_1.refreshUnreadMessageCount)(currentUserId);
    return { ok: true };
});
exports.archiveConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = {
        ...(0, state_1.readConversationFlagMap)(data, "archivedBy"),
        [currentUserId]: true,
    };
    const blockedBy = (0, state_1.readConversationFlagMap)(data, "blockedBy");
    await convRef.update({
        [`archivedBy.${currentUserId}`]: true,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
exports.unarchiveConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = {
        ...(0, state_1.readConversationFlagMap)(data, "archivedBy"),
        [currentUserId]: false,
    };
    const blockedBy = (0, state_1.readConversationFlagMap)(data, "blockedBy");
    await convRef.update({
        [`archivedBy.${currentUserId}`]: false,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
exports.blockConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = (0, state_1.readConversationFlagMap)(data, "archivedBy");
    const blockedBy = {
        ...(0, state_1.readConversationFlagMap)(data, "blockedBy"),
        [currentUserId]: true,
    };
    await convRef.update({
        [`blockedBy.${currentUserId}`]: true,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
exports.unblockConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    if (!(0, state_1.isConversationFlagEnabledForUser)(data, "blockedBy", currentUserId)) {
        return { ok: true };
    }
    const archivedBy = (0, state_1.readConversationFlagMap)(data, "archivedBy");
    const blockedBy = {
        ...(0, state_1.readConversationFlagMap)(data, "blockedBy"),
        [currentUserId]: false,
    };
    await convRef.update({
        [`blockedBy.${currentUserId}`]: false,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
exports.deleteConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    // Delete messages subcollection in batches
    const messagesRef = convRef.collection("messages");
    let batch = firestore_1.db.batch();
    let batchCount = 0;
    const BATCH_SIZE = 400;
    const messagesSnap = await messagesRef.limit(BATCH_SIZE).get();
    let remaining = messagesSnap.size;
    for (const doc of messagesSnap.docs) {
        batch.delete(doc.ref);
        batchCount++;
        if (batchCount >= BATCH_SIZE) {
            await batch.commit();
            batch = firestore_1.db.batch();
            batchCount = 0;
        }
    }
    if (batchCount > 0) {
        await batch.commit();
    }
    // If there could be more messages beyond the first batch, continue
    if (remaining >= BATCH_SIZE) {
        let moreSnap = await messagesRef.limit(BATCH_SIZE).get();
        while (moreSnap.size > 0) {
            const deleteBatch = firestore_1.db.batch();
            for (const doc of moreSnap.docs) {
                deleteBatch.delete(doc.ref);
            }
            await deleteBatch.commit();
            moreSnap = await messagesRef.limit(BATCH_SIZE).get();
        }
    }
    // Delete the conversation document itself
    await convRef.delete();
    // Refresh unread counts for all participants
    await Promise.all(participants.map((pid) => (0, counters_1.refreshUnreadMessageCount)(pid)));
    return { ok: true };
});
exports.deleteConversationMessage = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const messageId = String(request.data?.messageId || "").trim();
    if (!conversationId || !messageId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and messageId are required");
    }
    const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);
    const messageRef = convRef.collection("messages").doc(messageId);
    const messageSnap = await messageRef.get();
    if (!messageSnap.exists) {
        throw new https_1.HttpsError("not-found", "message not found");
    }
    const messageData = (messageSnap.data() ?? {});
    const senderId = String(messageData.senderId || "").trim();
    if (senderId !== currentUserId) {
        throw new https_1.HttpsError("permission-denied", "you can only delete your own messages");
    }
    await messageRef.delete();
    return { ok: true };
});
//# sourceMappingURL=callables.js.map