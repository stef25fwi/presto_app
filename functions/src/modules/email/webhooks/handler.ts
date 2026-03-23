import { onRequest } from "firebase-functions/v2/https";
import { createEmailProvider } from "../providers/provider_factory";
import { normalizeHeaders } from "./signature";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { mapProviderStatusToInternal } from "./mapper";
import { PROJECT_REGION } from "../../../config/env";

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
    await db.collection(COLLECTIONS.emailLogs).add({
      provider: provider.name(),
      provider_message_id: evt.providerMessageId || null,
      status: internalStatus,
      recipient: evt.recipient || null,
      created_at: Date.now(),
      webhook_event_id: evt.providerEventId,
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
