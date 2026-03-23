import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { EmailJob } from "../../../types/models";
import { TemplateCode } from "../../../types/templates";
import { createEmailProvider } from "../providers/provider_factory";
import { moveJobToDeadLetter } from "./dead_letter";
import { computeRetryDelayMs } from "./retry";
import { EMAIL_FROM } from "../../../config/env";
import { loadActiveTemplateVersion } from "../templates/loader";
import { getDefaultTemplateContent, getTemplateMeta } from "../templates/registry";
import { renderHtml } from "../renderer/render_html";
import { renderText } from "../renderer/render_text";

async function resolveTemplate(
  templateCode: string,
  locale: "fr" | "en",
  payload: Record<string, unknown>,
): Promise<{ subject: string; html: string; text: string }> {
  // 1. Essai depuis Firestore (versions dynamiques)
  const loaded = (await loadActiveTemplateVersion(templateCode, locale))
    || (locale === "en" ? await loadActiveTemplateVersion(templateCode, "fr") : null);
  if (loaded) {
    return {
      subject: renderText(loaded.subject, payload),
      html: renderHtml(loaded.html, payload),
      text: renderText(loaded.text, payload),
    };
  }

  // 2. Fallback sur le registre statique
  const meta = getTemplateMeta(templateCode);
  const subject = meta?.default_subject_fr ?? `PRESTO — ${templateCode}`;
  const preheader = meta?.default_preheader_fr ?? "";
  const content = getDefaultTemplateContent(templateCode as TemplateCode, locale);
  const htmlBody = renderHtml(content.html, { ...payload, subject, preheader });
  const textBody = renderText(content.text, { ...payload, subject, preheader });

  return { subject, html: htmlBody, text: textBody };
}

export async function processEmailJob(jobId: string): Promise<void> {
  const ref = db.collection(COLLECTIONS.emailJobs).doc(jobId);
  const snap = await ref.get();
  if (!snap.exists) return;

  const job = snap.data() as EmailJob;
  if (job.status !== "queued" && job.status !== "scheduled") return;
  if (Date.now() < job.send_at) return;

  await ref.set({ status: "processing", updated_at: Date.now() }, { merge: true });

  // Charger et rendre le template
  let subject: string;
  let html: string;
  let text: string;

  try {
    // Récupérer le payload stocké dans l'event source
    const eventSnap = await db.collection(COLLECTIONS.emailEvents).doc(job.event_id).get();
    const eventPayload = (eventSnap.data()?.payload as Record<string, unknown>) ?? {};

    const rendered = await resolveTemplate(job.template_code, job.locale as "fr" | "en", eventPayload);
    subject = rendered.subject;
    html = rendered.html;
    text = rendered.text;
  } catch (err) {
    logger.warn("email_job_template_render_failed", { jobId, error: String(err) });
    subject = `PRESTO — ${job.template_code}`;
    html = `<p>PRESTO — ${job.template_code}</p>`;
    text = `PRESTO — ${job.template_code}`;
  }

  const provider = createEmailProvider();

  const sendResult = await provider.send({
    to: job.recipient_email,
    from: EMAIL_FROM,
    subject,
    html,
    text,
    tags: [job.template_code, job.channel],
    metadata: {
      job_id: job.job_id,
      event_id: job.event_id,
    },
    idempotencyKey: job.idempotency_key,
    stream: job.channel === "marketing" ? "broadcast" : "transactional",
  });

  if (sendResult.accepted) {
    await ref.set(
      {
        status: "sent",
        updated_at: Date.now(),
        provider_message_id: sendResult.providerMessageId,
      },
      { merge: true },
    );

    await db.collection(COLLECTIONS.emailLogs).add({
      job_id: job.job_id,
      provider: provider.name(),
      provider_message_id: sendResult.providerMessageId || null,
      status: "sent",
      created_at: Date.now(),
    });

    logger.info("email_job_sent", { jobId: job.job_id, providerMessageId: sendResult.providerMessageId });
    return;
  }

  const nextAttempts = job.attempts + 1;
  if (nextAttempts >= job.max_attempts) {
    await moveJobToDeadLetter(job.job_id, sendResult.errorCode || "provider_rejected");
    return;
  }

  const delayMs = computeRetryDelayMs(nextAttempts - 1);
  await ref.set(
    {
      status: "scheduled",
      attempts: nextAttempts,
      send_at: Date.now() + delayMs,
      last_error_code: sendResult.errorCode || "provider_rejected",
      last_error_message: sendResult.errorMessage || "provider rejected request",
      updated_at: Date.now(),
    },
    { merge: true },
  );

  await db.collection(COLLECTIONS.emailLogs).add({
    job_id: job.job_id,
    provider: provider.name(),
    status: "failed",
    error_code: sendResult.errorCode || "provider_rejected",
    error_message: sendResult.errorMessage || "provider rejected request",
    created_at: Date.now(),
  });

  logger.warn("email_job_retry_scheduled", { jobId: job.job_id, attempts: nextAttempts, delayMs });
}
