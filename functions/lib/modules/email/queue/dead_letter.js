"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.moveJobToDeadLetter = moveJobToDeadLetter;
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
async function moveJobToDeadLetter(jobId, reason) {
    const now = Date.now();
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailJobs).doc(jobId).set({
        status: "dead_letter",
        dead_letter_reason: reason,
        updated_at: now,
    }, { merge: true });
    await firestore_1.db.collection(constants_1.COLLECTIONS.audits).add({
        action: "email.job.dead_letter",
        job_id: jobId,
        reason,
        created_at: now,
    });
}
//# sourceMappingURL=dead_letter.js.map