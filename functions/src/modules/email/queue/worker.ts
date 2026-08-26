import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { EmailJob } from "../../../types/models";
import { TemplateCode } from "../../../types/templates";
import { createEmailProvider } from "../providers/provider_factory";
import { moveJobToDeadLetter } from "./dead_letter";
import { computeRetryDelayMs } from "./retry";
import { EMAIL_FROM } from "../../../config/env";
import { APP_BASE_URL } from "../../../config/env";
import { getProviderName } from "../../../config/provider";
import { loadActiveTemplateVersion } from "../templates/loader";
import { applyFirestoreEmailBranding } from "../templates/branding";
import { getCompatDefaultTemplateContent, getCompatTemplateMeta } from "../templates/compat_registry";
import { renderHtml } from "../renderer/render_html";
import { renderText } from "../renderer/render_text";

function buildTemplateBrandPayload(): Record<string, string> {
  const appBaseUrl = APP_BASE_URL.replace(/\/+$/, "");

  return {
    appBaseUrl,
    brandLogoUrl: `${appBaseUrl}/assets/images/logowebp.webp`,
    brandLogoAlt: "iliprestō",
    brandName: "PRESTO",
    brandSignature: "iliprestō",
  };
}

function shouldApplyFirestoreBranding(category: string | undefined): boolean {
  return category === "account_auth"
    || category === "messaging"
    || category === "support"
    || category === "billing";
}

async function resolveTemplate(
  templateCode: string,
  locale: "fr" | "en",
  payload: Record<string, unknown>,
): Promise<{ subject: string; html: string; text: string }> {
  const meta = getCompatTemplateMeta(templateCode);
  const templatePayload = {
    ...payload,
    ...buildTemplateBrandPayload(),
  };

  // 1. Essai depuis Firestore (versions dynamiques)
  const loaded = (await loadActiveTemplateVersion(templateCode, locale))
    || (locale === "en" ? await loadActiveTemplateVersion(templateCode, "fr") : null);
  if (loaded) {
    const renderedPreheader = renderText(loaded.preheader, templatePayload);
    const htmlTemplate = shouldApplyFirestoreBranding(meta?.category)
      ? applyFirestoreEmailBranding(loaded.html, renderedPreheader)
      : loaded.html;

    return {
      subject: renderText(loaded.subject, templatePayload),
      html: renderHtml(htmlTemplate, templatePayload),
      text: renderText(loaded.text, templatePayload),
    };
  }

  // 2. Fallback sur le registre statique
  const subject = meta?.default_subject_fr ?? `PRESTO — ${templateCode}`;
  const preheader = meta?.default_preheader_fr ?? "";
  const content = getCompatDefaultTemplateContent(templateCode as TemplateCode, locale);
  const htmlBody = renderHtml(content.html, { ...templatePayload, subject, preheader });
  const textBody = renderText(content.text, { ...templatePayload, subject, preheader });

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

  let providerName = getProviderName();
  let sendResult;

  try {
    const provider = createEmailProvider();
    providerName = provider.name();
    sendResult = await provider.send({
      to: job.recipient_email,
      from: EMAIL_FROM,
      subject,
      html,
      text,
      // Le tag "production"/"production-certification" permet à
      // brevo_deliverability_report.mjs de ne mesurer que le trafic réel :
      // sans lui, le canari de certification (même pipeline, mêmes
      // job.template_code/channel qu'un envoi réel) fausserait l'échantillon.
      tags: [job.template_code, job.channel, job.is_certification ? "production-certification" : "production"],
      metadata: {
        job_id: job.job_id,
        event_id: job.event_id,
      },
      idempotencyKey: job.idempotency_key,
      stream: job.channel === "marketing" ? "broadcast" : "transactional",
    });
  } catch (err) {
    sendResult = {
      accepted: false,
      status: "rejected",
      errorCode: "provider_exception",
      errorMessage: String(err),
    };
    logger.error("email_job_provider_failed", { jobId: job.job_id, error: String(err), providerName });
  }

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
      event_id: job.event_id,
      template_code: job.template_code,
      channel: job.channel,
      recipient_user_id: job.recipient_user_id || null,
      recipient_email: job.recipient_email,
      provider: providerName,
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
    event_id: job.event_id,
    template_code: job.template_code,
    channel: job.channel,
    recipient_user_id: job.recipient_user_id || null,
    recipient_email: job.recipient_email,
    provider: providerName,
    status: "failed",
    error_code: sendResult.errorCode || "provider_rejected",
    error_message: sendResult.errorMessage || "provider rejected request",
    created_at: Date.now(),
  });

  logger.warn("email_job_retry_scheduled", { jobId: job.job_id, attempts: nextAttempts, delayMs });
}
