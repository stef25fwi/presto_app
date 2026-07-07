"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncMessagingAnalytics = exports.enqueueUnreadMessageReminders = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const env_1 = require("../../config/env");
const participants_1 = require("./participants");
exports.enqueueUnreadMessageReminders = (0, scheduler_1.onSchedule)("every 2 hours", async () => {
    const now = Date.now();
    const threshold = now - 24 * 60 * 60 * 1000;
    let query = firestore_1.db
        .collection(constants_1.COLLECTIONS.conversations)
        .where("lastMessageAt", "<=", threshold)
        .orderBy("lastMessageAt")
        .limit(200);
    let lastDoc;
    while (true) {
        const q = await query.get();
        if (q.empty)
            break;
        for (const doc of q.docs) {
            lastDoc = doc;
            const data = doc.data();
            const status = String(data.status || "open").toLowerCase();
            if (status !== "open" && status !== "active" && status.length > 0)
                continue;
            const participantIds = (0, participants_1.readConversationParticipants)(data, { conversationId: doc.id });
            const unreadCount = (data.unreadCount || data.unread_count || {});
            const reminderBucket = Math.floor(now / (12 * 60 * 60 * 1000));
            for (const uid of participantIds) {
                const userId = String(uid || "");
                if (!userId)
                    continue;
                const unread = Number(unreadCount[userId] || 0);
                if (unread <= 0)
                    continue;
                const user = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
                const email = String(user.data()?.email || "").trim();
                if (!email)
                    continue;
                const eventId = `evt_conv_reminder_${doc.id}_${userId}_${reminderBucket}`;
                await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
                    event_id: eventId,
                    event_name: "conversation.pending_reminder_due",
                    source_collection: constants_1.COLLECTIONS.conversations,
                    source_id: doc.id,
                    recipient_user_id: userId,
                    dedupe_key: (0, hash_1.sha256)(`conversation.pending_reminder_due:${doc.id}:${userId}:${reminderBucket}`),
                    occurred_at: now,
                    payload: {
                        recipient_email: email,
                        conversationUrl: `${env_1.APP_BASE_URL}/messages/${doc.id}`,
                    },
                    status: "created",
                }, { merge: true });
            }
        }
        if (q.size < 200 || !lastDoc)
            break;
        query = firestore_1.db
            .collection(constants_1.COLLECTIONS.conversations)
            .where("lastMessageAt", "<=", threshold)
            .orderBy("lastMessageAt")
            .startAfter(lastDoc)
            .limit(200);
    }
});
exports.syncMessagingAnalytics = (0, scheduler_1.onSchedule)("every 1 hours", async () => {
    const now = Date.now();
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const notificationThreshold = now - 60 * 60 * 1000;
    const totalConversations = (await firestore_1.db.collection(constants_1.COLLECTIONS.conversations).count().get()).data().count;
    const activeToday = (await firestore_1.db
        .collection(constants_1.COLLECTIONS.conversations)
        .where("lastMessageAt", ">=", startOfDay.getTime())
        .count()
        .get()).data().count;
    const reportedConversations = (await firestore_1.db.collection("message_reports").count().get()).data().count;
    const pendingNew = (await firestore_1.db.collection("message_reports").where("status", "==", "nouveau").count().get()).data().count;
    const pendingReview = (await firestore_1.db.collection("message_reports").where("status", "==", "en revue").count().get()).data().count;
    const pendingReports = pendingNew + pendingReview;
    const resolvedReports = Math.max(0, reportedConversations - pendingReports);
    const attachmentsCount = (await firestore_1.db.collection("message_attachments").count().get()).data().count;
    const watchlistedConversations = (await firestore_1.db
        .collection(constants_1.COLLECTIONS.conversations)
        .where("adminWatchlisted", "==", true)
        .count()
        .get()).data().count;
    const criticalRiskConversations = (await firestore_1.db
        .collection(constants_1.COLLECTIONS.conversations)
        .where("riskScore", ">=", 80)
        .count()
        .get()).data().count;
    let totalMessages = 0;
    let unansweredConversations = 0;
    let storageBytes = 0;
    let activeUsers = 0;
    let blockedUsers = 0;
    let averageResponseHoursTotal = 0;
    let averageResponseHoursCount = 0;
    let providerResponseRateTotal = 0;
    let providerResponseRateCount = 0;
    let conversationQuery = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).orderBy("updatedAt", "desc").limit(200);
    let lastConversationDoc;
    while (true) {
        const snapshot = await conversationQuery.get();
        if (snapshot.empty)
            break;
        for (const doc of snapshot.docs) {
            lastConversationDoc = doc;
            const data = doc.data();
            totalMessages += Number(data.messageCount || 0);
            const unreadCount = (data.unreadCount || data.unreadCounts || {});
            const hasUnread = Object.values(unreadCount).some((value) => Number(value || 0) > 0);
            if (hasUnread)
                unansweredConversations += 1;
        }
        if (snapshot.size < 200 || !lastConversationDoc)
            break;
        conversationQuery = firestore_1.db
            .collection(constants_1.COLLECTIONS.conversations)
            .orderBy("updatedAt", "desc")
            .startAfter(lastConversationDoc)
            .limit(200);
    }
    let attachmentQuery = firestore_1.db.collection("message_attachments").orderBy("createdAt", "desc").limit(200);
    let lastAttachmentDoc;
    while (true) {
        const snapshot = await attachmentQuery.get();
        if (snapshot.empty)
            break;
        for (const doc of snapshot.docs) {
            lastAttachmentDoc = doc;
            storageBytes += Number(doc.data().fileSize || 0);
        }
        if (snapshot.size < 200 || !lastAttachmentDoc)
            break;
        attachmentQuery = firestore_1.db
            .collection("message_attachments")
            .orderBy("createdAt", "desc")
            .startAfter(lastAttachmentDoc)
            .limit(200);
    }
    let usersQuery = firestore_1.db.collection(constants_1.COLLECTIONS.users).orderBy("updatedAt", "desc").limit(200);
    let lastUserDoc;
    while (true) {
        const snapshot = await usersQuery.get();
        if (snapshot.empty)
            break;
        for (const doc of snapshot.docs) {
            lastUserDoc = doc;
            const data = doc.data();
            const messagesSent = Number(data.messagesSent || 0);
            const openConversations = Number(data.messagingOpenConversations || 0);
            if (messagesSent > 0 || openConversations > 0)
                activeUsers += 1;
            const messagingStatus = String(data.messagingStatus || "").toLowerCase();
            if (messagingStatus === "bloqué" || messagingStatus === "suspendu") {
                blockedUsers += 1;
            }
            const avgResponse = Number(data.averageResponseHours || 0);
            if (avgResponse > 0) {
                averageResponseHoursTotal += avgResponse;
                averageResponseHoursCount += 1;
            }
            const role = String(data.primaryRole || data.role || "").toLowerCase();
            const isProvider = role.includes("provider") ||
                role.includes("prestataire") ||
                role.includes("seller") ||
                role.includes("vendeur") ||
                role.includes("pro");
            if (isProvider) {
                providerResponseRateTotal += Number(data.messagingResponseRate || 0);
                providerResponseRateCount += 1;
            }
        }
        if (snapshot.size < 200 || !lastUserDoc)
            break;
        usersQuery = firestore_1.db
            .collection(constants_1.COLLECTIONS.users)
            .orderBy("updatedAt", "desc")
            .startAfter(lastUserDoc)
            .limit(200);
    }
    const notificationSnapshot = await firestore_1.db
        .collection(constants_1.COLLECTIONS.notifications)
        .where("createdAt", ">=", notificationThreshold)
        .orderBy("createdAt", "desc")
        .limit(1000)
        .get();
    let pushSentCount = 0;
    let pushDeliveredCount = 0;
    let pushFailedCount = 0;
    for (const doc of notificationSnapshot.docs) {
        const data = doc.data();
        const routeName = String(data.routeName || "");
        const conversationId = String(data.conversationId || "");
        if (!conversationId && !routeName.includes("/messages"))
            continue;
        const status = String(data.deliveryStatus || data.status || "").toLowerCase();
        if (status.includes("sent") || status.includes("envoy"))
            pushSentCount += 1;
        if (status.includes("deliver") || status.includes("recu"))
            pushDeliveredCount += 1;
        if (status.includes("fail") || status.includes("error") || status.includes("erreur"))
            pushFailedCount += 1;
    }
    const averageResponseHours = averageResponseHoursCount === 0 ? 0 : averageResponseHoursTotal / averageResponseHoursCount;
    const providerResponseRate = providerResponseRateCount === 0 ? 0 : providerResponseRateTotal / providerResponseRateCount;
    await firestore_1.db.collection(constants_1.COLLECTIONS.systemSettings).doc("messaging_dashboard_current").set({
        generatedAt: now,
        source: "scheduled",
        windowHours: 1,
        sampledNotifications: notificationSnapshot.size,
        totalConversations,
        activeToday,
        totalMessages,
        unansweredConversations,
        reportedConversations,
        blockedUsers,
        attachmentsCount,
        storageBytes,
        activeUsers,
        watchlistedConversations,
        criticalRiskConversations,
        pendingReports,
        resolvedReports,
        averageResponseHours,
        providerResponseRate,
        pushSentCount,
        pushDeliveredCount,
        pushFailedCount,
    }, { merge: true });
});
//# sourceMappingURL=scheduled.js.map