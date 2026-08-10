import { onRequest } from "firebase-functions/v2/https";
import { createEmailProvider } from "../providers/provider_factory";
import { normalizeHeaders } from "./signature";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { mapProviderStatusToInternal } from "./mapper";
import { PROJECT_REGION } from "../../../config/env";
import { sha256 } from "../../../utils/hash";

function mapWebhookStatusToJobStatus(
  status: string,
  bounceKind?: "soft" | "hard",
): "delivered" | "failed" | "cancelled" | null {
  switch (status) {
    case "delivered":
      return "delivered";
    case "bounced":
      // A soft bounce is temporary and must never permanently fail/suppress
      // the recipient. Brevo can still recover delivery provider-side.
      return bounceKind === "hard" ? "failed" : null;
    case "complained":
    case "dropped":
      return "failed";
    case "unsubscribed":
      return "cancelled";
    default:
      return null;
  }
}

export const handleEmailProviderWebhook = onRequest({ region: PROJECT_REGION }, async (req, res) => {
  if (req.method !== "POST") {
    res.set("Allow", "POST");
    res.status(405).json({ ok: false, error: "method not allowed" });
    return;
  }

  const provider = createEmailProvider();
  const rawBody = typeof req.rawBody === "string" ? req.rawBody : req.rawBody?.toString("utf8") || "";
  const headers = normalizeHeaders(req.headers);

  const signatureValid = provider.verifyWebhookSignature(headers, rawBody);
  await db.collection(COLLECTIONS.emailProviderWebhooks).add({
    provider: provider.name(),
    // Do not persist attacker-controlled payloads when authentication failed.
    raw_payload: signatureValid ? req.body : null,
    payload_bytes: Buffer.byteLength(rawBody, "utf8"),
    signature_valid: signatureValid,
    received_at: Date.now(),
    processing_status: signatureValid ? "accepted" : "rejected",
  });

  if (!signatureValid) {
    res.status(401).json({ ok: false, error: "invalid webhook authentication" });
    return;
  }

  const events = provider.parseWebhook(req.body);
  for (const evt of events) {
    const internalStatus = mapProviderStatusToInternal(evt.type);
    let jobMetadata: Record<string, unknown> = {};
    let eventId: string | null = null;

    if (evt.providerMessageId) {
      const jobSnap = await db
        .collection(COLLECTIONS.emailJobs)
        .where("provider_message_id", "==", evt.providerMessageId)
        .limit(1)
        .get();
      const jobDoc = jobSnap.docs[0];
      const jobData = jobDoc?.data();
      if (jobDoc && jobData) {
        eventId = typeof jobData.event_id === "string" && jobData.event_id.trim().length > 0
          ? jobData.event_id
          : null;
        jobMetadata = {
          job_id: jobData.job_id || jobDoc.id,
          event_id: eventId,
          template_code: jobData.template_code || null,
          channel: jobData.channel || null,
          recipient_user_id: jobData.recipient_user_id || null,
          recipient_email: jobData.recipient_email || null,
        };

        const nextJobStatus = mapWebhookStatusToJobStatus(internalStatus, evt.bounceKind);
        await jobDoc.ref.set({
          last_provider_event_status: internalStatus,
          last_provider_event_at: evt.occurredAt,
          ...(evt.bounceKind ? { last_provider_bounce_kind: evt.bounceKind } : {}),
          updated_at: Date.now(),
          ...(nextJobStatus ? { status: nextJobStatus } : {}),
        }, { merge: true });

        if (eventId) {
          await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
            last_provider_event_status: internalStatus,
            last_provider_event_at: evt.occurredAt,
            ...(evt.bounceKind ? { last_provider_bounce_kind: evt.bounceKind } : {}),
            ...(internalStatus === "delivered" ? { delivery_status: "delivered" } : {}),
          }, { merge: true });
        }
      }
    }

    // Brevo's payload `id` is the webhook id, not an event id. The provider
    // generates a stable event key; use it as the Firestore log id so webhook
    // retries cannot duplicate analytics or suppression effects.
    const providerLogId = `provider_${sha256(`${provider.name()}:${evt.providerEventId}`).slice(0, 40)}`;
    await db.collection(COLLECTIONS.emailLogs).doc(providerLogId).set({
      provider: provider.name(),
      provider_message_id: evt.providerMessageId || null,
      status: internalStatus,
      bounce_kind: evt.bounceKind || null,
      recipient: evt.recipient || null,
      provider_event_at: evt.occurredAt,
      created_at: evt.occurredAt,
      webhook_received_at: Date.now(),
      webhook_event_id: evt.providerEventId,
      ...jobMetadata,
    }, { merge: true });

    const shouldSuppress = internalStatus === "complained"
      || internalStatus === "unsubscribed"
      || (internalStatus === "bounced" && evt.bounceKind === "hard");

    if (shouldSuppress) {
      const email = String(evt.recipient || "").trim().toLowerCase();
      if (email) {
        await db.collection(COLLECTIONS.emailSuppressions).doc(email).set(
          {
            email,
            reason: internalStatus === "bounced"
              ? "hard_bounce"
              : internalStatus === "complained"
                ? "complaint"
                : "unsubscribe_all",
            source: "provider_webhook",
            active: true,
            created_at: Date.now(),
            updated_at: Date.now(),
          },
          { merge: true },
        );
      }
    }
  }

  res.status(200).json({ ok: true, processed: events.length });
});
