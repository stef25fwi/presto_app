"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleEmailProviderWebhook = void 0;
const https_1 = require("firebase-functions/v2/https");
const provider_factory_1 = require("../providers/provider_factory");
const signature_1 = require("./signature");
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const mapper_1 = require("./mapper");
exports.handleEmailProviderWebhook = (0, https_1.onRequest)(async (req, res) => {
    const provider = (0, provider_factory_1.createEmailProvider)();
    const rawBody = typeof req.rawBody === "string" ? req.rawBody : req.rawBody?.toString("utf8") || "";
    const headers = (0, signature_1.normalizeHeaders)(req.headers);
    const signatureValid = provider.verifyWebhookSignature(headers, rawBody);
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailProviderWebhooks).add({
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
        const internalStatus = (0, mapper_1.mapProviderStatusToInternal)(evt.type);
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailLogs).add({
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
                await firestore_1.db.collection(constants_1.COLLECTIONS.emailSuppressions).doc(email).set({
                    email,
                    reason: internalStatus === "bounced" ? "hard_bounce" : internalStatus === "complained" ? "complaint" : "unsubscribe_all",
                    source: "provider_webhook",
                    active: true,
                    created_at: Date.now(),
                }, { merge: true });
            }
        }
    }
    res.status(200).json({ ok: true, processed: events.length });
});
//# sourceMappingURL=handler.js.map