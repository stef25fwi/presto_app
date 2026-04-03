"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueEmailJobsFromEvent = enqueueEmailJobsFromEvent;
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const mapper_1 = require("../events/mapper");
const enrich_1 = require("../events/enrich");
const resolver_1 = require("../preferences/resolver");
const compat_registry_1 = require("../templates/compat_registry");
const hash_1 = require("../../../utils/hash");
async function enqueueEmailJobsFromEvent(event) {
    const enrichedEvent = await (0, enrich_1.enrichEventPayload)(event);
    const template = (0, mapper_1.mapEventToTemplate)(enrichedEvent.event_name);
    if (!template) {
        logger_1.logger.info("email_enqueue_skipped_no_template", { eventId: enrichedEvent.event_id, eventName: enrichedEvent.event_name });
        return;
    }
    const meta = (0, compat_registry_1.getCompatTemplateMeta)(template);
    if (!meta) {
        logger_1.logger.warn("email_enqueue_skipped_unknown_template_meta", { eventId: enrichedEvent.event_id, template });
        return;
    }
    const recipientUserId = enrichedEvent.recipient_user_id;
    const recipientEmail = String(enrichedEvent.payload.recipient_email || "").trim();
    if (!recipientEmail) {
        logger_1.logger.warn("email_enqueue_skipped_no_recipient_email", { eventId: enrichedEvent.event_id });
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
            eventId: enrichedEvent.event_id,
            email: recipientEmail,
            reason: suppressionSnap.docs[0]?.data()?.reason ?? "suppressed",
        });
        return;
    }
    const missingVariables = (0, compat_registry_1.listCompatMissingRequiredVariables)(template, enrichedEvent.payload);
    if (missingVariables.length > 0) {
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(enrichedEvent.event_id).set({
            status: "ignored",
            ignore_reason: "missing_required_variables",
            missing_required_variables: missingVariables,
            updated_at: Date.now(),
        }, { merge: true });
        logger_1.logger.warn("email_enqueue_skipped_missing_required_variables", {
            eventId: enrichedEvent.event_id,
            template,
            missingVariables,
        });
        return;
    }
    const topic = meta.preference_topic
        ?? (meta.category === "messaging"
            ? "messaging"
            : meta.category === "listings"
                ? "listings"
                : meta.category === "saved_search"
                    ? "saved_search"
                    : "other");
    const channel = meta.channel;
    const decision = await (0, resolver_1.resolvePreferenceDecision)(recipientUserId, channel, topic);
    if (!decision.allowed) {
        logger_1.logger.info("email_enqueue_skipped_by_preferences", {
            eventId: enrichedEvent.event_id,
            reason: decision.reason,
            channel,
        });
        return;
    }
    const now = Date.now();
    const idempotencyKey = (0, hash_1.sha256)(`${enrichedEvent.event_id}:${template}:${recipientEmail}`);
    const jobId = `job_${idempotencyKey.slice(0, 24)}`;
    const job = {
        job_id: jobId,
        event_id: enrichedEvent.event_id,
        recipient_user_id: recipientUserId,
        recipient_email: recipientEmail,
        channel,
        template_code: template,
        template_version: 1,
        locale: decision.locale || "fr",
        priority: channel === "transactionnel" ? "high" : "normal",
        status: "queued",
        send_at: decision.sendAtMs || now,
        expires_at: now + 7 * 24 * 60 * 60 * 1000,
        attempts: 0,
        max_attempts: channel === "transactionnel" ? 5 : 4,
        idempotency_key: idempotencyKey,
        payload_hash: (0, hash_1.sha256)(JSON.stringify(enrichedEvent.payload || {})),
        created_at: now,
        updated_at: now,
    };
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailJobs).doc(jobId).set(job, { merge: false });
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(enrichedEvent.event_id).set({
        status: "jobs_created",
        payload: enrichedEvent.payload,
        updated_at: now,
    }, { merge: true });
    logger_1.logger.info("email_job_enqueued", { eventId: enrichedEvent.event_id, jobId, template });
}
//# sourceMappingURL=enqueue.js.map