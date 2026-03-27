"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.markConversationRead = exports.sendConversationMessage = exports.ensureOfferConversation = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
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
async function loadConversationForParticipant(conversationId, currentUserId) {
    const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
        throw new https_1.HttpsError("not-found", "conversation not found");
    }
    const data = (convSnap.data() ?? {});
    const participants = Array.isArray(data.participants)
        ? data.participants.map((value) => String(value || "").trim()).filter(Boolean)
        : [];
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
    const existing = await convCol
        .where("participants", "array-contains", currentUserId)
        .where("offerId", "==", offerId)
        .limit(20)
        .get();
    for (const doc of existing.docs) {
        const participants = Array.isArray(doc.data().participants)
            ? doc.data().participants
                .map((value) => String(value || "").trim())
                .filter(Boolean)
            : [];
        if (!participants.includes(otherUserId))
            continue;
        await doc.ref.set({
            participantNames,
            otherUserName,
            updatedAt: Date.now(),
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
            transaction.set(convRef, {
                participantNames,
                otherUserName,
                updatedAt: Date.now(),
            }, { merge: true });
            return;
        }
        transaction.set(convRef, {
            offerId,
            offerTitle,
            participants,
            participantNames,
            otherUserName,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: Date.now(),
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessage: "",
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
    const text = String(request.data?.text || "").trim();
    if (!conversationId || !text) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and text are required");
    }
    if (text.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "message is too long");
    }
    const { convRef, participants } = await loadConversationForParticipant(conversationId, currentUserId);
    const senderUserSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(currentUserId).get();
    const senderName = readUserDisplayName(senderUserSnap.data(), request.auth?.token?.name, request.auth?.token?.email, currentUserId);
    const messageRef = convRef.collection("messages").doc();
    const batch = firestore_1.db.batch();
    batch.set(messageRef, {
        text,
        senderId: currentUserId,
        senderName,
        createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    const conversationUpdate = {
        lastMessage: text,
        lastSenderId: currentUserId,
        lastSenderName: senderName,
        lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        updatedAt: Date.now(),
        [`participantNames.${currentUserId}`]: senderName,
    };
    for (const participantId of participants) {
        conversationUpdate[`unreadCount.${participantId}`] = participantId == currentUserId
            ? 0
            : firebase_admin_1.default.firestore.FieldValue.increment(1);
    }
    batch.update(convRef, conversationUpdate);
    await batch.commit();
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
        updatedAt: Date.now(),
    });
    return { ok: true };
});
//# sourceMappingURL=callables.js.map