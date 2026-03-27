"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createInAppNotification = createInAppNotification;
exports.sendPushToUser = sendPushToUser;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const FCM_MULTICAST_TOKEN_LIMIT = 500;
function readBoolean(value, fallback = true) {
    return typeof value === "boolean" ? value : fallback;
}
function toStringMap(data) {
    const out = {};
    for (const [key, value] of Object.entries(data)) {
        if (value == null)
            continue;
        out[key] = String(value);
    }
    return out;
}
async function isPushEnabledForUser(userId, topic) {
    const prefsSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.notificationPreferences).doc(userId).get();
    const prefs = prefsSnap.data();
    const pushPrefs = prefs?.push || {};
    const topicPrefs = pushPrefs[topic] || {};
    return readBoolean(topicPrefs.enabled, true);
}
async function listPushTokens(userId) {
    const snap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.users)
        .doc(userId)
        .collection(constants_1.COLLECTIONS.pushTokens)
        .get();
    return snap.docs
        .map((doc) => {
        const token = String(doc.data().token || "").trim();
        const enabled = doc.data().enabled !== false;
        return enabled && token ? { docId: doc.id, token } : null;
    })
        .filter((entry) => entry != null);
}
async function cleanupInvalidTokens(userId, docIds) {
    if (docIds.length === 0)
        return;
    const batch = firestore_1.db.batch();
    for (const docId of docIds) {
        batch.delete(firestore_1.db.collection(constants_1.COLLECTIONS.users)
            .doc(userId)
            .collection(constants_1.COLLECTIONS.pushTokens)
            .doc(docId));
    }
    await batch.commit();
}
async function createInAppNotification({ notificationId, userId, title, message, type, routeName, conversationId, offerId, data = {}, }) {
    try {
        await firestore_1.db.collection(constants_1.COLLECTIONS.notifications).doc(notificationId).create({
            userId,
            title,
            message,
            type,
            routeName: routeName || null,
            conversationId: conversationId || null,
            offerId: offerId || null,
            data,
            read: false,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        const code = error.code;
        if (code !== 6) {
            throw error;
        }
    }
}
async function sendPushToUser({ userId, topic, title, body, routeName, channelId, collapseKey, data = {}, }) {
    const enabled = await isPushEnabledForUser(userId, topic);
    if (!enabled)
        return;
    const tokenEntries = await listPushTokens(userId);
    if (tokenEntries.length === 0)
        return;
    const invalidDocIds = new Set();
    for (let index = 0; index < tokenEntries.length; index += FCM_MULTICAST_TOKEN_LIMIT) {
        const batchEntries = tokenEntries.slice(index, index + FCM_MULTICAST_TOKEN_LIMIT);
        const multicast = {
            tokens: batchEntries.map((entry) => entry.token),
            notification: {
                title,
                body,
            },
            data: toStringMap({
                ...data,
                routeName,
                channelId,
            }),
            android: {
                priority: "high",
                collapseKey,
                notification: {
                    channelId,
                    tag: collapseKey,
                    sound: "default",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                },
            },
            apns: {
                headers: {
                    "apns-priority": "10",
                },
                payload: {
                    aps: {
                        sound: "default",
                        contentAvailable: true,
                    },
                },
            },
        };
        const response = await firebase_admin_1.default.messaging().sendEachForMulticast(multicast);
        response.responses.forEach((result, responseIndex) => {
            if (result.success)
                return;
            const code = result.error?.code || "";
            if (code === "messaging/registration-token-not-registered" ||
                code === "messaging/invalid-registration-token") {
                invalidDocIds.add(batchEntries[responseIndex].docId);
            }
        });
    }
    await cleanupInvalidTokens(userId, Array.from(invalidDocIds));
}
//# sourceMappingURL=push.js.map