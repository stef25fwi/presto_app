import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { DomainEventPayload } from "../../../types/events";
import { EmailJob } from "../../../types/models";
import { mapEventToTemplate } from "../events/mapper";
import { enrichEventPayload } from "../events/enrich";
import { resolvePreferenceDecision } from "../preferences/resolver";
import { getCompatTemplateMeta, listCompatMissingRequiredVariables } from "../templates/compat_registry";
import { sha256 } from "../../../utils/hash";

/** Les suppressions sont indexées sur l'adresse normalisée en minuscules. */
export function normalizeSuppressionKey(email: string): string {
  return email.trim().toLowerCase();
}

export function isActiveSuppression(data: FirebaseFirestore.DocumentData | undefined): boolean {
  return data?.active === true;
}

async function findActiveSuppression(
  suppressionKey: string,
): Promise<FirebaseFirestore.DocumentData | null> {
  const doc = await db.collection(COLLECTIONS.emailSuppressions).doc(suppressionKey).get();
  const data = doc.data();
  if (doc.exists && isActiveSuppression(data)) return data ?? null;

  // Repli sur les documents historiques dont l'identifiant n'est pas l'adresse.
  const snap = await db
    .collection(COLLECTIONS.emailSuppressions)
    .where("email", "==", suppressionKey)
    .where("active", "==", true)
    .limit(1)
    .get();
  return snap.docs[0]?.data() ?? null;
}

export async function enqueueEmailJobsFromEvent(event: DomainEventPayload): Promise<void> {
  const enrichedEvent = await enrichEventPayload(event);
  const template = mapEventToTemplate(enrichedEvent.event_name);
  if (!template) {
    logger.info("email_enqueue_skipped_no_template", { eventId: enrichedEvent.event_id, eventName: enrichedEvent.event_name });
    return;
  }

  const meta = getCompatTemplateMeta(template);
  if (!meta) {
    logger.warn("email_enqueue_skipped_unknown_template_meta", { eventId: enrichedEvent.event_id, template });
    return;
  }

  const recipientUserId = enrichedEvent.recipient_user_id;
  const recipientEmail = String(enrichedEvent.payload.recipient_email || "").trim();
  if (!recipientEmail) {
    logger.warn("email_enqueue_skipped_no_recipient_email", { eventId: enrichedEvent.event_id });
    return;
  }

  // Vérification liste de suppression (hard bounce / plainte). Le webhook
  // fournisseur écrit toujours une adresse normalisée : interroger la casse
  // brute laisserait repartir des envois vers une adresse déjà supprimée.
  const suppressionKey = normalizeSuppressionKey(recipientEmail);
  const suppression = await findActiveSuppression(suppressionKey);
  if (suppression) {
    logger.info("email_enqueue_skipped_suppressed", {
      eventId: enrichedEvent.event_id,
      email: suppressionKey,
      reason: suppression.reason ?? "suppressed",
    });
    return;
  }

  const missingVariables = listCompatMissingRequiredVariables(template, enrichedEvent.payload);
  if (missingVariables.length > 0) {
    await db.collection(COLLECTIONS.emailEvents).doc(enrichedEvent.event_id).set(
      {
        status: "ignored",
        ignore_reason: "missing_required_variables",
        missing_required_variables: missingVariables,
        updated_at: Date.now(),
      },
      { merge: true },
    );
    logger.warn("email_enqueue_skipped_missing_required_variables", {
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
  const decision = await resolvePreferenceDecision(recipientUserId, channel, topic);
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
    // Firestore refuse `undefined` sans `ignoreUndefinedProperties` : omettre
    // le champ plutôt que d'y assigner `recipientUserId` quand l'événement
    // n'a pas d'utilisateur (envoi transactionnel anonyme, canari de
    // certification), sous peine de faire planter le déclencheur d'enqueue
    // avant même la mise à jour de statut de `email_events`.
    ...(recipientUserId ? { recipient_user_id: recipientUserId } : {}),
    // Marque les envois issus du canari de certification (brevo_runtime_canary.mjs,
    // source_collection: "brevo_certification_canary") pour que le worker les
    // taggue distinctement chez Brevo et qu'ils n'entrent pas dans l'échantillon
    // de délivrabilité de production (functions/scripts/brevo_deliverability_report.mjs).
    ...(enrichedEvent.source_collection === "brevo_certification_canary" ? { is_certification: true } : {}),
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
