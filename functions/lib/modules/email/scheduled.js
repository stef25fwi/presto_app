"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncEmailAnalytics = exports.purgeOldEmailLogs = exports.purgeOldEmailWebhooks = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
exports.purgeOldEmailWebhooks = (0, scheduler_1.onSchedule)("every day 04:00", async () => {
    const threshold = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const q = await firestore_1.db.collection(constants_1.COLLECTIONS.emailProviderWebhooks).where("received_at", "<", threshold).limit(500).get();
    for (const doc of q.docs) {
        await doc.ref.delete();
    }
});
exports.purgeOldEmailLogs = (0, scheduler_1.onSchedule)("every day 04:30", async () => {
    const threshold = Date.now() - 90 * 24 * 60 * 60 * 1000;
    const q = await firestore_1.db.collection(constants_1.COLLECTIONS.emailLogs).where("created_at", "<", threshold).limit(500).get();
    for (const doc of q.docs) {
        await doc.ref.delete();
    }
});
exports.syncEmailAnalytics = (0, scheduler_1.onSchedule)("every 1 hours", async () => {
    await firestore_1.db.collection(constants_1.COLLECTIONS.audits).add({
        action: "email.analytics.sync",
        created_at: Date.now(),
    });
});
//# sourceMappingURL=scheduled.js.map