"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteConversationMessage = exports.deleteConversation = exports.unblockConversation = exports.blockConversation = exports.unarchiveConversation = exports.archiveConversation = exports.markConversationRead = exports.sendConversationMessage = exports.ensureOfferConversation = void 0;
exports.resolveOfferLikeData = resolveOfferLikeData;
exports.mergeConversationParticipants = mergeConversationParticipants;
exports.computeUnreadCountAfterMessageDeletion = computeUnreadCountAfterMessageDeletion;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const counters_1 = require("../notifications/counters");
const state_1 = require("./state");
const participants_1 = require("./participants");
const mirror_1 = require("./mirror");
const MESSAGE_SEND_WINDOW_MS = 10 * 1000;
const MESSAGE_SEND_LIMIT = 6;
const DUPLICATE_MESSAGE_WINDOW_MS = 15 * 1000;
async function findConversationSnapshotsForParticipant(currentUserId, offerId) {
    const conversationCollection = firestore_1.db.collection(constants_1.COLLECTIONS.conversations);
    const offerFieldAliases = offerId ? ["offerId", "offer_id"] : [null];
    const snapshots = await Promise.all(participants_1.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.flatMap((participantField) => offerFieldAliases.map((offerField) => {
        let query = conversationCollection.where(participantField, "array-contains", currentUserId);
        if (offerId && offerField) {
            query = query.where(offerField, "==", offerId);
        }
        return query.limit(20).get();
    })));
    const deduped = new Map();
    for (const snapshot of snapshots) {
        for (const doc of snapshot.docs) {
            deduped.set(doc.id, doc);
        }
    }
    return [...deduped.values()];
}
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
async function deleteNotificationsForConversation(conversationId) {
    const routeName = `/messages/${encodeURIComponent(conversationId)}`;
    const [conversationIdSnap, routeNameSnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.notifications).where("conversationId", "==", conversationId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.notifications).where("routeName", "==", routeName).get(),
    ]);
    const notificationDocs = new Map();
    for (const snapshot of [conversationIdSnap, routeNameSnap]) {
        for (const doc of snapshot.docs) {
            notificationDocs.set(doc.id, doc);
        }
    }
    if (notificationDocs.size == 0) {
        return new Set();
    }
    let batch = firestore_1.db.batch();
    let batchCount = 0;
    const affectedUserIds = new Set();
    for (const doc of notificationDocs.values()) {
        batch.delete(doc.ref);
        batchCount += 1;
        const userId = String(doc.data().userId || "").trim();
        if (userId) {
            affectedUserIds.add(userId);
        }
        if (batchCount >= 400) {
            await batch.commit();
            batch = firestore_1.db.batch();
            batchCount = 0;
        }
    }
    if (batchCount > 0) {
        await batch.commit();
    }
    return affectedUserIds;
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
function resolveOfferLikeData({ offerData, listingData, }) {
    if (offerData != null) {
        return { data: offerData, source: "offers" };
    }
    if (listingData != null) {
        return { data: listingData, source: "listings" };
    }
    throw new https_1.HttpsError("not-found", "offer not found");
}
async function loadOfferLikeSnapshot(offerId) {
    const [offerSnap, listingSnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.offers).doc(offerId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(offerId).get(),
    ]);
    return resolveOfferLikeData({
        offerData: offerSnap.exists
            ? (offerSnap.data() ?? {})
            : null,
        listingData: listingSnap.exists
            ? (listingSnap.data() ?? {})
            : null,
    });
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
function mergeConversationParticipants(existingParticipants, requiredParticipants) {
    return [...existingParticipants, ...requiredParticipants]
        .map((value) => String(value || "").trim())
        .filter(Boolean)
        .filter((value, index, all) => all.indexOf(value) === index)
        .sort();
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
function computeUnreadCountAfterMessageDeletion({ participants, unreadCount, lastReadAt, deletedSenderId, deletedCreatedAt, }) {
    const result = {};
    for (const participantId of participants) {
        const currentUnread = Number(unreadCount[participantId] || 0);
        if (participantId === deletedSenderId || deletedCreatedAt == null) {
            result[participantId] = Math.max(0, currentUnread);
            continue;
        }
        const lastReadAtForParticipant = toDateOrNull(lastReadAt[participantId]);
        const shouldDecrement = !lastReadAtForParticipant || deletedCreatedAt > lastReadAtForParticipant;
        result[participantId] = Math.max(0, currentUnread - (shouldDecrement ? 1 : 0));
    }
    return result;
}
async function loadConversationForParticipant(conversationId, currentUserId) {
    const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
        throw new https_1.HttpsError("not-found", "conversation not found");
    }
    const data = (convSnap.data() ?? {});
    const conversation = (0, mirror_1.readConversationMirrorData)(data, { conversationId });
    const participants = conversation.participants;
    if (!participants.includes(currentUserId)) {
        throw new https_1.HttpsError("permission-denied", "not allowed to access this conversation");
    }
    return { convRef, data, participants, conversation };
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
    const { data: offerData, source: offerSource } = await loadOfferLikeSnapshot(offerId);
    const offerOwnerId = readOfferOwnerId(offerData);
    if (!offerOwnerId) {
        throw new https_1.HttpsError("failed-precondition", `${offerSource} owner is missing`);
    }
    if (offerOwnerId != otherUserId) {
        throw new https_1.HttpsError("permission-denied", `conversation target does not match ${offerSource} owner`);
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
    const existingDocs = await findConversationSnapshotsForParticipant(currentUserId, offerId);
    for (const doc of existingDocs) {
        const docData = doc.data();
        const conversation = (0, mirror_1.readConversationMirrorData)(docData, { conversationId: doc.id });
        if (!conversation.participants.includes(otherUserId))
            continue;
        const normalizedParticipants = mergeConversationParticipants(conversation.participants, [currentUserId, otherUserId]);
        if ((0, state_1.isConversationBlocked)(docData)) {
            throw new https_1.HttpsError("failed-precondition", "conversation is blocked");
        }
        const archivedBy = {
            ...conversation.archivedBy,
            [currentUserId]: false,
        };
        const blockedBy = conversation.blockedBy;
        await doc.ref.set((0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants: normalizedParticipants,
            participantNames: {
                ...conversation.participantNames,
                ...participantNames,
            },
            otherUserName,
            offerId,
            offerTitle,
            archivedBy,
            blockedBy,
            status: (0, state_1.computeConversationStatus)(normalizedParticipants, archivedBy, blockedBy),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }), { merge: true });
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
            const conversation = (0, mirror_1.readConversationMirrorData)(data, { conversationId: convRef.id });
            const normalizedParticipants = mergeConversationParticipants(conversation.participants, participants);
            const archivedBy = {
                ...conversation.archivedBy,
                [currentUserId]: false,
            };
            const blockedBy = conversation.blockedBy;
            transaction.set(convRef, (0, mirror_1.buildConversationMirrorFields)({
                ...conversation,
                participants: normalizedParticipants,
                participantNames: {
                    ...conversation.participantNames,
                    ...participantNames,
                },
                otherUserName,
                offerId,
                offerTitle,
                archivedBy,
                blockedBy,
                status: (0, state_1.computeConversationStatus)(normalizedParticipants, archivedBy, blockedBy),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }), { merge: true });
            return;
        }
        transaction.set(convRef, (0, mirror_1.buildConversationMirrorFields)({
            participants,
            participantNames,
            otherUserName,
            offerId,
            offerTitle,
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
                [currentUserId]: 0,
                [otherUserId]: 0,
            },
        }));
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
        const conversation = (0, mirror_1.readConversationMirrorData)(data, { conversationId });
        const participants = conversation.participants;
        if (!participants.includes(currentUserId)) {
            throw new https_1.HttpsError("permission-denied", "not allowed to access this conversation");
        }
        if ((0, state_1.isConversationBlocked)(data)) {
            throw new https_1.HttpsError("failed-precondition", "conversation is blocked");
        }
        const isFirstMessage = (0, mirror_1.readConversationMessageCount)(data) === 0;
        transaction.set(messageRef, {
            text,
            body: text,
            senderId: currentUserId,
            sender_id: currentUserId,
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
            unreadCount[participantId] = participantId == currentUserId
                ? 0
                : firebase_admin_1.default.firestore.FieldValue.increment(1);
        }
        transaction.update(convRef, (0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants,
            participantNames: {
                ...conversation.participantNames,
                [currentUserId]: senderName,
            },
            archivedBy,
            unreadCount,
            lastMessage: text,
            lastSenderId: currentUserId,
            lastSenderName: senderName,
            status: "open",
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            messageCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
        }));
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
    const { convRef, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        unreadCount: {
            ...conversation.unreadCount,
            [currentUserId]: 0,
        },
        lastReadAt: {
            ...conversation.lastReadAt,
            [currentUserId]: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    await (0, counters_1.refreshUnreadMessageCount)(currentUserId);
    return { ok: true };
});
exports.archiveConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = {
        ...conversation.archivedBy,
        [currentUserId]: true,
    };
    const blockedBy = conversation.blockedBy;
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.unarchiveConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = {
        ...conversation.archivedBy,
        [currentUserId]: false,
    };
    const blockedBy = conversation.blockedBy;
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.blockConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = conversation.archivedBy;
    const blockedBy = {
        ...conversation.blockedBy,
        [currentUserId]: true,
    };
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.unblockConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    if (!(0, state_1.isConversationFlagEnabledForUser)(data, "blockedBy", currentUserId)) {
        return { ok: true };
    }
    const archivedBy = (0, state_1.readConversationFlagMap)(data, "archivedBy");
    const blockedBy = {
        ...conversation.blockedBy,
        [currentUserId]: false,
    };
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.deleteConversation = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    const notificationUserIds = await deleteNotificationsForConversation(conversationId);
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
    await Promise.all(Array.from(notificationUserIds, (userId) => (0, counters_1.refreshUnreadNotificationCount)(userId)));
    return { ok: true };
});
exports.deleteConversationMessage = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const messageId = String(request.data?.messageId || "").trim();
    if (!conversationId || !messageId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and messageId are required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const messageRef = convRef.collection("messages").doc(messageId);
    const messageSnap = await messageRef.get();
    if (!messageSnap.exists) {
        throw new https_1.HttpsError("not-found", "message not found");
    }
    const messageData = (messageSnap.data() ?? {});
    const senderId = String(messageData.senderId || messageData.sender_id || "").trim();
    const deletedCreatedAt = toDateOrNull(messageData.createdAt || messageData.created_at);
    if (senderId !== currentUserId) {
        throw new https_1.HttpsError("permission-denied", "you can only delete your own messages");
    }
    await messageRef.delete();
    const messagesRef = convRef.collection("messages");
    const [latestMessageSnap, messageCountSnap] = await Promise.all([
        messagesRef.orderBy("createdAt", "desc").limit(1).get(),
        messagesRef.count().get(),
    ]);
    const latestMessage = latestMessageSnap.docs[0]?.data();
    const remainingMessageCount = messageCountSnap.data().count;
    const unreadCount = computeUnreadCountAfterMessageDeletion({
        participants,
        unreadCount: conversation.unreadCount,
        lastReadAt: conversation.lastReadAt,
        deletedSenderId: senderId,
        deletedCreatedAt,
    });
    const archivedBy = {
        ...conversation.archivedBy,
    };
    for (const participantId of participants) {
        archivedBy[participantId] = false;
    }
    await convRef.set((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        unreadCount,
        archivedBy,
        lastMessage: latestMessage
            ? sanitizeMessageText(latestMessage.text ?? latestMessage.body)
            : "",
        lastSenderId: latestMessage
            ? String(latestMessage.senderId || latestMessage.sender_id || "").trim()
            : "",
        lastSenderName: latestMessage
            ? normalizeParticipantName(latestMessage.senderName, latestMessage.sender_name)
            : "",
        lastMessageAt: latestMessage?.createdAt ?? latestMessage?.created_at,
        messageCount: remainingMessageCount,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, conversation.blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }), { merge: true });
    await Promise.all(participants.map((participantId) => (0, counters_1.refreshUnreadMessageCount)(participantId)));
    return { ok: true };
});
//# sourceMappingURL=callables.js.map