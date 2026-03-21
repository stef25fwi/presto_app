"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupExpiredEmailJobs = exports.retryFailedEmailJobs = exports.processScheduledEmailDigests = exports.processEmailJobTrigger = exports.enqueueEmailJobsFromEventTrigger = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_2 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const enqueue_1 = require("./enqueue");
const worker_1 = require("./worker");
exports.enqueueEmailJobsFromEventTrigger = (0, firestore_1.onDocumentCreated)("email_events/{eventId}", async (event) => {
    const payload = event.data?.data();
    if (!payload)
        return;
    await (0, enqueue_1.enqueueEmailJobsFromEvent)(payload);
});
exports.processEmailJobTrigger = (0, firestore_1.onDocumentCreated)("email_jobs/{jobId}", async (event) => {
    const jobId = event.params.jobId;
    await (0, worker_1.processEmailJob)(jobId);
});
exports.processScheduledEmailDigests = (0, scheduler_1.onSchedule)("every 15 minutes", async () => {
    // Placeholder for digest generation pipeline (daily/weekly by timezone bucket).
    await firestore_2.db.collection(constants_1.COLLECTIONS.audits).add({
        action: "digest.scheduler.tick",
        created_at: Date.now(),
    });
});
exports.retryFailedEmailJobs = (0, scheduler_1.onSchedule)("every 30 minutes", async () => {
    const now = Date.now();
    const q = await firestore_2.db
        .collection(constants_1.COLLECTIONS.emailJobs)
        .where("status", "==", "scheduled")
        .where("send_at", "<=", now)
        .limit(100)
        .get();
    for (const doc of q.docs) {
        await (0, worker_1.processEmailJob)(doc.id);
    }
});
exports.cleanupExpiredEmailJobs = (0, scheduler_1.onSchedule)("every day 03:15", async () => {
    const now = Date.now();
    const q = await firestore_2.db
        .collection(constants_1.COLLECTIONS.emailJobs)
        .where("expires_at", "<", now)
        .where("status", "in", ["queued", "scheduled"])
        .limit(300)
        .get();
    for (const doc of q.docs) {
        await doc.ref.set({ status: "cancelled", updated_at: now }, { merge: true });
    }
});
//# sourceMappingURL=triggers.js.map