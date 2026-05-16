"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncEmailAnalytics = exports.purgeOldEmailLogs = exports.purgeOldEmailWebhooks = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("../../core/firestore");
const logger_1 = require("../../core/logger");
const constants_1 = require("../../shared/constants");
const alerts_1 = require("./analytics/alerts");
exports.purgeOldEmailWebhooks = (0, scheduler_1.onSchedule)("every day 04:00", async () => {
    const threshold = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const q = await firestore_1.db.collection(constants_1.COLLECTIONS.emailProviderWebhooks).where("received_at", "<", threshold).limit(500).get();
    if (q.empty)
        return;
    const batch = firestore_1.db.batch();
    for (const doc of q.docs)
        batch.delete(doc.ref);
    await batch.commit();
});
exports.purgeOldEmailLogs = (0, scheduler_1.onSchedule)("every day 04:30", async () => {
    const threshold = Date.now() - 90 * 24 * 60 * 60 * 1000;
    const q = await firestore_1.db.collection(constants_1.COLLECTIONS.emailLogs).where("created_at", "<", threshold).limit(500).get();
    if (q.empty)
        return;
    const batch = firestore_1.db.batch();
    for (const doc of q.docs)
        batch.delete(doc.ref);
    await batch.commit();
});
exports.syncEmailAnalytics = (0, scheduler_1.onSchedule)("every 1 hours", async () => {
    const threshold = Date.now() - 60 * 60 * 1000;
    const logsSnap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.emailLogs)
        .where("created_at", ">=", threshold)
        .limit(1000)
        .get();
    const metrics = {
        sent: 0,
        delivered: 0,
        bounced: 0,
        complained: 0,
        failed: 0,
    };
    const byProvider = {};
    const byTemplate = {};
    for (const doc of logsSnap.docs) {
        const data = doc.data();
        const status = String(data.status || "");
        const provider = String(data.provider || "unknown");
        const templateCode = String(data.template_code || "unknown");
        byProvider[provider] ??= { sent: 0, delivered: 0, bounced: 0, complained: 0, failed: 0 };
        byTemplate[templateCode] ??= { sent: 0, delivered: 0, bounced: 0, complained: 0, failed: 0 };
        if (status === "sent")
            metrics.sent += 1;
        if (status === "delivered")
            metrics.delivered += 1;
        if (status === "bounced")
            metrics.bounced += 1;
        if (status === "complained")
            metrics.complained += 1;
        if (status === "failed")
            metrics.failed += 1;
        if (status === "sent") {
            byProvider[provider].sent += 1;
            byTemplate[templateCode].sent += 1;
        }
        if (status === "delivered") {
            byProvider[provider].delivered += 1;
            byTemplate[templateCode].delivered += 1;
        }
        if (status === "bounced") {
            byProvider[provider].bounced += 1;
            byTemplate[templateCode].bounced += 1;
        }
        if (status === "complained") {
            byProvider[provider].complained += 1;
            byTemplate[templateCode].complained += 1;
        }
        if (status === "failed") {
            byProvider[provider].failed += 1;
            byTemplate[templateCode].failed += 1;
        }
    }
    const deadLettersSnap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.emailJobs)
        .where("status", "==", "dead_letter")
        .limit(200)
        .get();
    const recentDeadLetters = deadLettersSnap.docs.filter((doc) => {
        const updatedAt = Number(doc.data().updated_at || 0);
        return updatedAt >= threshold;
    }).length;
    (0, alerts_1.triggerDeliverabilityAlerts)(metrics);
    if (recentDeadLetters > 0) {
        logger_1.logger.warn("email_dead_letters_detected", { recentDeadLetters });
    }
    await firestore_1.db.collection(constants_1.COLLECTIONS.systemSettings).doc("email_dashboard_current").set({
        updated_at: Date.now(),
        window_hours: 1,
        metrics,
        recent_dead_letters: recentDeadLetters,
        sampled_logs: logsSnap.size,
        by_provider: byProvider,
        by_template: byTemplate,
    }, { merge: true });
});
//# sourceMappingURL=scheduled.js.map