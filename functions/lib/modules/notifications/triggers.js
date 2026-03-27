"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNotificationUpdated = exports.onNotificationCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const counters_1 = require("./counters");
exports.onNotificationCreated = (0, firestore_1.onDocumentCreated)("notifications/{notificationId}", async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    const userId = String(data.userId || "").trim();
    if (!userId)
        return;
    await (0, counters_1.refreshUnreadNotificationCount)(userId);
});
exports.onNotificationUpdated = (0, firestore_1.onDocumentUpdated)("notifications/{notificationId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after)
        return;
    const userIds = new Set();
    for (const raw of [before?.userId, after.userId]) {
        const userId = String(raw || "").trim();
        if (userId)
            userIds.add(userId);
    }
    await Promise.all(Array.from(userIds, (userId) => (0, counters_1.refreshUnreadNotificationCount)(userId)));
});
//# sourceMappingURL=triggers.js.map