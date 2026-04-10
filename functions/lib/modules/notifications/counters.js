"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.refreshUnreadMessageCount = refreshUnreadMessageCount;
exports.refreshUnreadNotificationCount = refreshUnreadNotificationCount;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const CONVERSATION_PRIMARY_PARTICIPANT_FIELD = "participants";
function safeNumber(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}
function readBoolMap(value) {
    if (!value || typeof value != "object")
        return {};
    const out = {};
    for (const [key, item] of Object.entries(value)) {
        out[key] = item === true;
    }
    return out;
}
async function setInboxCounts(userId, unreadMessages, unreadNotifications) {
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).set({
        inboxCounts: {
            unreadMessages: Math.max(0, unreadMessages),
            unreadNotifications: Math.max(0, unreadNotifications),
            totalUnread: Math.max(0, unreadMessages) + Math.max(0, unreadNotifications),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        },
    }, { merge: true });
}
async function refreshUnreadMessageCount(userId) {
    const snapshot = await firestore_1.db.collection(constants_1.COLLECTIONS.conversations)
        .where(CONVERSATION_PRIMARY_PARTICIPANT_FIELD, "array-contains", userId)
        .get();
    let unreadMessages = 0;
    for (const doc of snapshot.docs) {
        const data = doc.data();
        const archivedBy = readBoolMap(data.archivedBy);
        const blockedBy = readBoolMap(data.blockedBy);
        const status = String(data.status || "").trim().toLowerCase();
        // Ignore conversations archived by this user or explicitly closed for this user.
        if (archivedBy[userId] === true || blockedBy[userId] === true || status == "closed") {
            continue;
        }
        const unreadMap = (data.unreadCount || data.unread_count || {});
        unreadMessages += safeNumber(unreadMap[userId]);
    }
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const inboxCounts = (userSnap.data()?.inboxCounts || {});
    const unreadNotifications = safeNumber(inboxCounts.unreadNotifications);
    await setInboxCounts(userId, unreadMessages, unreadNotifications);
}
async function refreshUnreadNotificationCount(userId) {
    const notificationsSnap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.notifications)
        .where("userId", "==", userId)
        .where("read", "==", false)
        .get();
    const unreadNotifications = notificationsSnap.size;
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const inboxCounts = (userSnap.data()?.inboxCounts || {});
    const unreadMessages = safeNumber(inboxCounts.unreadMessages);
    await setInboxCounts(userId, unreadMessages, unreadNotifications);
}
//# sourceMappingURL=counters.js.map