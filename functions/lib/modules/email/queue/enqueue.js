"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueEmailJobsFromEvent = enqueueEmailJobsFromEvent;
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const mapper_1 = require("../events/mapper");
const resolver_1 = require("../preferences/resolver");
const hash_1 = require("../../../utils/hash");
async function enqueueEmailJobsFromEvent(event) {
    const template = (0, mapper_1.mapEventToTemplate)(event.event_name);
    if (!template) {
        logger_1.logger.info("email_enqueue_skipped_no_template", { eventId: event.event_id, eventName: event.event_name });
        return;
    }
    const recipientUserId = event.recipient_user_id;
    const recipientEmail = String(event.payload.recipient_email || "").trim();
    if (!recipientEmail) {
        logger_1.logger.warn("email_enqueue_skipped_no_recipient_email", { eventId: event.event_id });
        return;
    }
    // Vérification liste de suppression (hard bounce / plainte)
    const suppressionSnap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.emailSuppressions)
        .where("email", "==", recipientEmail)
        .where("active", "==", true)
        .limit(1)
        .get();
    if (!suppressionSnap.empty) {
        logger_1.logger.info("email_enqueue_skipped_suppressed", {
            eventId: event.event_id,
            email: recipientEmail,
            reason: suppressionSnap.docs[0]?.data()?.reason ?? "suppressed",
        });
        return;
    }
    const channel = template.includes("marketing") ? "marketing" : template.includes("product") ? "produit" : "transactionnel";
    const decision = await (0, resolver_1.resolvePreferenceDecision)(recipientUserId, channel);
    if (!decision.allowed) {
        logger_1.logger.info("email_enqueue_skipped_by_preferences", {
            eventId: event.event_id,
            reason: decision.reason,
            channel,
        });
        return;
    }
    const now = Date.now();
    const idempotencyKey = (0, hash_1.sha256)(`${event.event_id}:${template}:${recipientEmail}`);
    const jobId = `job_${idempotencyKey.slice(0, 24)}`;
    const job = {
        job_id: jobId,
        event_id: event.event_id,
        recipient_user_id: recipientUserId,
        recipient_email: recipientEmail,
        channel,
        template_code: template,
        template_version: 1,
        locale: "fr",
        priority: channel === "transactionnel" ? "high" : "normal",
        status: "queued",
        send_at: decision.sendAtMs || now,
        expires_at: now + 7 * 24 * 60 * 60 * 1000,
        attempts: 0,
        max_attempts: channel === "transactionnel" ? 5 : 4,
        idempotency_key: idempotencyKey,
        payload_hash: (0, hash_1.sha256)(JSON.stringify(event.payload || {})),
        created_at: now,
        updated_at: now,
    };
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailJobs).doc(jobId).set(job, { merge: false });
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(event.event_id).set({
        status: "jobs_created",
        updated_at: now,
    }, { merge: true });
    logger_1.logger.info("email_job_enqueued", { eventId: event.event_id, jobId, template });
}
//# sourceMappingURL=enqueue.js.map