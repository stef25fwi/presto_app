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
const participants_1 = require("../messaging/participants");
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
    const snapshots = await Promise.all(participants_1.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.map((field) => firestore_1.db.collection(constants_1.COLLECTIONS.conversations)
        .where(field, "array-contains", userId)
        .get()));
    const seen = new Set();
    let unreadMessages = 0;
    for (const doc of snapshots.flatMap((snapshot) => snapshot.docs)) {
        if (seen.has(doc.id))
            continue;
        seen.add(doc.id);
        const unreadMap = (doc.data().unreadCount || doc.data().unread_count || {});
        unreadMessages += Number(unreadMap[userId] || 0);
    }
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const inboxCounts = (userSnap.data()?.inboxCounts || {});
    const unreadNotifications = Number(inboxCounts.unreadNotifications || 0);
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
    const unreadMessages = Number(inboxCounts.unreadMessages || 0);
    await setInboxCounts(userId, unreadMessages, unreadNotifications);
}
//# sourceMappingURL=counters.js.map