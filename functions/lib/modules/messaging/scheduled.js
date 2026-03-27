"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueUnreadMessageReminders = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
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
            const participantIds = Array.isArray(data.participants)
                ? data.participants
                : Array.isArray(data.participant_ids)
                    ? data.participant_ids
                    : [];
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
                        conversationUrl: `https://presto.app/messages/${doc.id}`,
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
//# sourceMappingURL=scheduled.js.map