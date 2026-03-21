import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { DomainEventPayload } from "../../../types/events";
import { EmailJob } from "../../../types/models";
import { mapEventToTemplate } from "../events/mapper";
import { enrichEventPayload } from "../events/enrich";
import { resolvePreferenceDecision } from "../preferences/resolver";
import { sha256 } from "../../../utils/hash";

export async function enqueueEmailJobsFromEvent(event: DomainEventPayload): Promise<void> {
  const enrichedEvent = await enrichEventPayload(event);
  const template = mapEventToTemplate(enrichedEvent.event_name);
  if (!template) {
    logger.info("email_enqueue_skipped_no_template", { eventId: enrichedEvent.event_id, eventName: enrichedEvent.event_name });
    return;
  }

  const recipientUserId = enrichedEvent.recipient_user_id;
  const recipientEmail = String(enrichedEvent.payload.recipient_email || "").trim();
  if (!recipientEmail) {
    logger.warn("email_enqueue_skipped_no_recipient_email", { eventId: enrichedEvent.event_id });
    return;
  }

  // Vérification liste de suppression (hard bounce / plainte)
  const suppressionSnap = await db
    .collection(COLLECTIONS.emailSuppressions)
    .where("email", "==", recipientEmail)
    .where("active", "==", true)
    .limit(1)
    .get();
  if (!suppressionSnap.empty) {
    logger.info("email_enqueue_skipped_suppressed", {
      eventId: enrichedEvent.event_id,
      email: recipientEmail,
      reason: suppressionSnap.docs[0]?.data()?.reason ?? "suppressed",
    });
    return;
  }

  const channel = template.includes("marketing") ? "marketing" : template.includes("product") ? "produit" : "transactionnel";
  const decision = await resolvePreferenceDecision(recipientUserId, channel);
  if (!decision.allowed) {
    logger.info("email_enqueue_skipped_by_preferences", {
      eventId: enrichedEvent.event_id,
      reason: decision.reason,
      channel,
    });
    return;
  }

  const now = Date.now();
  const idempotencyKey = sha256(`${enrichedEvent.event_id}:${template}:${recipientEmail}`);
  const jobId = `job_${idempotencyKey.slice(0, 24)}`;

  const job: EmailJob = {
    job_id: jobId,
    event_id: enrichedEvent.event_id,
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
    payload_hash: sha256(JSON.stringify(enrichedEvent.payload || {})),
    created_at: now,
    updated_at: now,
  };

  await db.collection(COLLECTIONS.emailJobs).doc(jobId).set(job, { merge: false });
  await db.collection(COLLECTIONS.emailEvents).doc(enrichedEvent.event_id).set(
    {
      status: "jobs_created",
      payload: enrichedEvent.payload,
      updated_at: now,
    },
    { merge: true },
  );

  logger.info("email_job_enqueued", { eventId: enrichedEvent.event_id, jobId, template });
}
