import { onRequest } from "firebase-functions/v2/https";
import { createEmailProvider } from "../providers/provider_factory";
import { normalizeHeaders } from "./signature";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { mapProviderStatusToInternal } from "./mapper";
import { PROJECT_REGION } from "../../../config/env";

function mapWebhookStatusToJobStatus(status: string): "delivered" | "failed" | "cancelled" | null {
  switch (status) {
    case "delivered":
      return "delivered";
    case "bounced":
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
  const provider = createEmailProvider();
  const rawBody = typeof req.rawBody === "string" ? req.rawBody : req.rawBody?.toString("utf8") || "";
  const headers = normalizeHeaders(req.headers);

  const signatureValid = provider.verifyWebhookSignature(headers, rawBody);
  await db.collection(COLLECTIONS.emailProviderWebhooks).add({
    provider: provider.name(),
    raw_payload: req.body,
    signature_valid: signatureValid,
    received_at: Date.now(),
    processing_status: signatureValid ? "accepted" : "rejected",
  });

  if (!signatureValid) {
    res.status(401).json({ ok: false, error: "invalid signature" });
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

        const nextJobStatus = mapWebhookStatusToJobStatus(internalStatus);
        await jobDoc.ref.set({
          last_provider_event_status: internalStatus,
          last_provider_event_at: Date.now(),
          updated_at: Date.now(),
          ...(nextJobStatus ? { status: nextJobStatus } : {}),
        }, { merge: true });

        if (eventId) {
          await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
            last_provider_event_status: internalStatus,
            last_provider_event_at: Date.now(),
            ...(internalStatus === "delivered" ? { delivery_status: "delivered" } : {}),
          }, { merge: true });
        }
      }
    }

    await db.collection(COLLECTIONS.emailLogs).add({
      provider: provider.name(),
      provider_message_id: evt.providerMessageId || null,
      status: internalStatus,
      recipient: evt.recipient || null,
      created_at: Date.now(),
      webhook_event_id: evt.providerEventId,
      ...jobMetadata,
    });

    if (internalStatus === "bounced" || internalStatus === "complained" || internalStatus === "unsubscribed") {
      const email = evt.recipient || "";
      if (email) {
        await db.collection(COLLECTIONS.emailSuppressions).doc(email).set(
          {
            email,
            reason: internalStatus === "bounced" ? "hard_bounce" : internalStatus === "complained" ? "complaint" : "unsubscribe_all",
            source: "provider_webhook",
            active: true,
            created_at: Date.now(),
          },
          { merge: true },
        );
      }
    }
  }

  res.status(200).json({ ok: true, processed: events.length });
});
