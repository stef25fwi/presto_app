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
const push_1 = require("../../notifications/push");
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
function buildThreadId(listingId, participants) {
    return `${listingId}__${participants.sort().join("__")}`;
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
        const ownerId = normalizeString(listingData.ownerId);
        if (!ownerId || ownerId === senderId) {
            throw new https_1.HttpsError("failed-precondition", "Cannot open a thread on your own listing");
        }
        const threadId = buildThreadId(listingId, [senderId, ownerId]);
        const threadRef = firestore_1.db.collection(constants_1.COLLECTIONS.chatThreads).doc(threadId);
        const messageRef = threadRef.collection("messages").doc();
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        await firestore_1.db.runTransaction(async (transaction) => {
            const threadSnap = await transaction.get(threadRef);
            const unreadCountByUser = {
                [senderId]: 0,
                [ownerId]: 1,
            };
            if (!threadSnap.exists) {
                transaction.set(threadRef, {
                    id: threadId,
                    listingId,
                    ownerId,
                    buyerId: senderId,
                    participants: [senderId, ownerId].sort(),
                    status: "open",
                    lastMessageAt: now,
                    lastMessagePreview: body.slice(0, 160),
                    unreadCountByUser,
                    blockedBy: {},
                    createdAt: now,
                    updatedAt: now,
                });
            }
            else {
                transaction.set(threadRef, {
                    lastMessageAt: now,
                    lastMessagePreview: body.slice(0, 160),
                    unreadCountByUser,
                    updatedAt: now,
                }, { merge: true });
            }
            transaction.set(messageRef, {
                id: messageRef.id,
                threadId,
                listingId,
                senderId,
                body,
                moderationStatus: "clean",
                createdAt: now,
            });
        });
        await (0, push_1.createInAppNotification)({
            notificationId: `chat_message_${messageRef.id}`,
            userId: ownerId,
            title: "Nouveau message",
            message: body.slice(0, 120),
            type: "new_chat_message",
            routeName: `/chat/${encodeURIComponent(threadId)}`,
            conversationId: threadId,
            offerId: listingId,
        });
        await (0, analytics_1.trackProductEventBackend)({
            eventName: "listing_message_started",
            userId: senderId,
            listingId,
            threadId,
        });
        return {
            ok: true,
            threadId,
            messageId: messageRef.id,
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
        const threadRef = firestore_1.db.collection(constants_1.COLLECTIONS.chatThreads).doc(threadId);
        const threadSnap = await threadRef.get();
        if (!threadSnap.exists) {
            throw new https_1.HttpsError("not-found", "Thread not found");
        }
        const threadData = (threadSnap.data() ?? {});
        const participants = Array.isArray(threadData.participants)
            ? threadData.participants.map((value) => normalizeString(value)).filter(Boolean)
            : [];
        if (!participants.includes(senderId)) {
            throw new https_1.HttpsError("permission-denied", "You are not a participant of this thread");
        }
        const blockedBy = (threadData.blockedBy ?? {});
        if (blockedBy[senderId] === true) {
            throw new https_1.HttpsError("failed-precondition", "Thread is blocked for this participant");
        }
        const recipientId = participants.find((participantId) => participantId !== senderId) || "";
        const messageRef = threadRef.collection("messages").doc();
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        const unreadCountByUser = {
            ...(threadData.unreadCountByUser ?? {}),
            [senderId]: 0,
            [recipientId]: Number((threadData.unreadCountByUser ?? {})[recipientId] || 0) + 1,
        };
        await firestore_1.db.runTransaction(async (transaction) => {
            transaction.set(messageRef, {
                id: messageRef.id,
                threadId,
                listingId: normalizeString(threadData.listingId),
                senderId,
                body,
                moderationStatus: "clean",
                createdAt: now,
            });
            transaction.set(threadRef, {
                lastMessageAt: now,
                lastMessagePreview: body.slice(0, 160),
                unreadCountByUser,
                updatedAt: now,
            }, { merge: true });
        });
        if (recipientId) {
            await (0, push_1.createInAppNotification)({
                notificationId: `chat_message_${messageRef.id}`,
                userId: recipientId,
                title: "Nouveau message",
                message: body.slice(0, 120),
                type: "new_chat_message",
                routeName: `/chat/${encodeURIComponent(threadId)}`,
                conversationId: threadId,
                offerId: normalizeString(threadData.listingId),
            });
        }
        logger_1.logger.info("marketplace_chat_message_sent", {
            threadId,
            senderId,
            messageId: messageRef.id,
        });
        return {
            ok: true,
            messageId: messageRef.id,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to send chat message");
    }
});
//# sourceMappingURL=chat.js.map