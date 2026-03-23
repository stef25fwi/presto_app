"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BrevoProvider = void 0;
const crypto_1 = require("crypto");
class BrevoProvider {
    apiKey;
    webhookSecret;
    constructor(apiKey, webhookSecret) {
        this.apiKey = apiKey;
        this.webhookSecret = webhookSecret;
    }
    name() {
        return "brevo";
    }
    async send(input) {
        if (!this.apiKey) {
            return {
                accepted: false,
                status: "rejected",
                errorCode: "provider_api_key_missing",
                errorMessage: "BREVO API key is not configured",
            };
        }
        try {
            const body = {
                sender: this.parseSender(input.from),
                to: [{ email: input.to }],
                subject: input.subject,
                htmlContent: input.html,
                textContent: input.text,
                tags: input.tags,
                headers: input.idempotencyKey ? { "X-Idempotency-Key": input.idempotencyKey } : undefined,
                params: input.metadata,
            };
            const response = await fetch("https://api.brevo.com/v3/smtp/email", {
                method: "POST",
                headers: {
                    "api-key": this.apiKey,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(body),
            });
            if (response.ok) {
                const data = (await response.json().catch(() => ({})));
                const providerMessageId = data.messageId ? String(data.messageId) : `brevo_${Date.now()}`;
                return {
                    accepted: true,
                    status: "accepted",
                    providerMessageId,
                };
            }
            const errorData = (await response.json().catch(() => ({})));
            return {
                accepted: false,
                status: "rejected",
                errorCode: errorData.code ?? `http_${response.status}`,
                errorMessage: errorData.message ?? `Brevo API error ${response.status}`,
            };
        }
        catch (err) {
            return {
                accepted: false,
                status: "rejected",
                errorCode: "network_error",
                errorMessage: String(err),
            };
        }
    }
    verifyWebhookSignature(headers, rawBody) {
        if (!this.webhookSecret)
            return false;
        const signature = headers["x-mailin-signature"] || headers["X-Mailin-Signature"];
        if (!signature)
            return false;
        try {
            const expectedHex = (0, crypto_1.createHmac)("sha256", this.webhookSecret).update(rawBody).digest("hex");
            const expectedB64 = Buffer.from(expectedHex, "hex").toString("base64");
            const normalized = signature.replace(/^sha256=/i, "").trim();
            return this.constantTimeEqual(normalized, expectedHex) || this.constantTimeEqual(normalized, expectedB64);
        }
        catch {
            return false;
        }
    }
    parseWebhook(raw) {
        const payloads = Array.isArray(raw) ? raw : [raw];
        const out = [];
        for (let idx = 0; idx < payloads.length; idx += 1) {
            const item = payloads[idx];
            if (!item || typeof item !== "object")
                continue;
            const payload = item;
            const event = String(payload.event || payload.type || "sent").toLowerCase();
            const typeMap = {
                sent: "sent",
                delivered: "delivered",
                deferred: "deferred",
                soft_bounce: "bounced",
                hard_bounce: "bounced",
                blocked: "dropped",
                invalid: "dropped",
                error: "dropped",
                failed: "dropped",
                softbounce: "bounced",
                hardbounce: "bounced",
                spam: "complained",
                complaint: "complained",
                opened: "opened",
                unique_opened: "opened",
                click: "clicked",
                clicked: "clicked",
                unique_clicked: "clicked",
                unsubscribed: "unsubscribed",
            };
            const occurredAt = this.resolveEventTimestamp(payload);
            const messageId = payload["message-id"] ? String(payload["message-id"]) : payload.messageId ? String(payload.messageId) : undefined;
            out.push({
                providerEventId: String(payload.id ?? payload.event_id ?? messageId ?? `evt_${occurredAt}_${idx}`),
                providerMessageId: messageId,
                type: typeMap[event] ?? "sent",
                recipient: payload.email ? String(payload.email) : undefined,
                occurredAt,
                raw: payload,
            });
        }
        return out;
    }
    parseSender(from) {
        const m = from.match(/^(.*)<([^>]+)>$/);
        if (!m)
            return { email: from.trim() };
        const name = m[1]?.trim().replace(/^"|"$/g, "");
        const email = m[2]?.trim() || from.trim();
        return name ? { email, name } : { email };
    }
    constantTimeEqual(a, b) {
        const aBuf = Buffer.from(a, "utf8");
        const bBuf = Buffer.from(b, "utf8");
        if (aBuf.length !== bBuf.length)
            return false;
        return (0, crypto_1.timingSafeEqual)(aBuf, bBuf);
    }
    resolveEventTimestamp(payload) {
        const timestampCandidates = [
            payload.date,
            payload.ts,
            payload.timestamp,
            payload.time,
            payload.created_at,
        ];
        for (const candidate of timestampCandidates) {
            if (typeof candidate === "number" && Number.isFinite(candidate)) {
                return candidate > 10_000_000_000 ? Math.trunc(candidate) : Math.trunc(candidate * 1000);
            }
            if (typeof candidate === "string" && candidate.trim().length > 0) {
                const asNumber = Number(candidate);
                if (Number.isFinite(asNumber) && asNumber > 0) {
                    return asNumber > 10_000_000_000 ? Math.trunc(asNumber) : Math.trunc(asNumber * 1000);
                }
                const asDate = Date.parse(candidate);
                if (!Number.isNaN(asDate))
                    return asDate;
            }
        }
        return Date.now();
    }
}
exports.BrevoProvider = BrevoProvider;
//# sourceMappingURL=brevo_provider.js.map