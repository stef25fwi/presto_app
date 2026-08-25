import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { createEmailProvider } from "./providers/provider_factory";
import { renderHtml } from "./renderer/render_html";
import { renderText } from "./renderer/render_text";

export interface RenderTemplateInput {
  templateCode: string;
  locale: "fr" | "en";
  data: Record<string, unknown>;
  subject: string;
  html: string;
  text: string;
}

export interface RenderTemplateResult {
  subject: string;
  html: string;
  text: string;
}

export function renderTemplate(input: RenderTemplateInput): RenderTemplateResult {
  return {
    subject: input.subject,
    html: renderHtml(input.html, input.data),
    text: renderText(input.text, input.data),
  };
}

export async function sendTransactionalEmail(jobId: string): Promise<void> {
  await db.collection(COLLECTIONS.audits).add({ action: "email.send_transactional", job_id: jobId, created_at: Date.now() });
}

export async function sendMarketingEmail(jobId: string): Promise<void> {
  await db.collection(COLLECTIONS.audits).add({ action: "email.send_marketing", job_id: jobId, created_at: Date.now() });
}

export async function sendDigestEmail(jobId: string): Promise<void> {
  await db.collection(COLLECTIONS.audits).add({ action: "email.send_digest", job_id: jobId, created_at: Date.now() });
}

export async function suppressRecipient(email: string, reason: string): Promise<void> {
  // Même clé de normalisation que le webhook fournisseur et que l'enqueue,
  // sans quoi une suppression manuelle laisserait passer les envois suivants.
  const normalized = email.trim().toLowerCase();
  await db.collection(COLLECTIONS.emailSuppressions).doc(normalized).set(
    {
      email: normalized,
      reason,
      source: "system",
      active: true,
      created_at: Date.now(),
    },
    { merge: true },
  );
}

export async function handleWebhook(rawBody: unknown): Promise<void> {
  const provider = createEmailProvider();
  const events = provider.parseWebhook(rawBody);
  await db.collection(COLLECTIONS.audits).add({
    action: "email.webhook.parsed",
    provider: provider.name(),
    count: events.length,
    created_at: Date.now(),
  });
}
