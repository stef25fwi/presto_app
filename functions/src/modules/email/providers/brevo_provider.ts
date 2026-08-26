import { createHash, createHmac, timingSafeEqual } from "crypto";
import { EmailProvider, NormalizedWebhookEvent, ProviderSendInput, ProviderSendResult } from "./email_provider.interface";

export class BrevoProvider implements EmailProvider {
  private readonly apiKey: string;
  private readonly webhookSecret: string;

  constructor(apiKey: string, webhookSecret: string) {
    // Les jetons entrants sont comparés après `trim()` : conserver ici une
    // valeur non normalisée rendrait toute vérification faussement négative si
    // le secret stocké porte un espace ou un saut de ligne final.
    this.apiKey = String(apiKey || "").trim();
    this.webhookSecret = String(webhookSecret || "").trim();
  }

  name(): string {
    return "brevo";
  }

  async send(input: ProviderSendInput): Promise<ProviderSendResult> {
    if (!this.apiKey) {
      return {
        accepted: false,
        status: "rejected",
        errorCode: "provider_api_key_missing",
        errorMessage: "BREVO API key is not configured",
      };
    }

    try {
      const replyTo = String(process.env.EMAIL_REPLY_TO || "contact@ilipresto.fr").trim();
      const body: Record<string, unknown> = {
        sender: this.parseSender(input.from),
        to: [{ email: input.to }],
        replyTo: replyTo ? { email: replyTo } : undefined,
        subject: input.subject,
        htmlContent: input.html,
        textContent: input.text,
        tags: input.tags,
        // Brevo supports an idempotency key in transactional email headers.
        // Convert the internal deterministic hash to a UUID-shaped key so
        // provider retries remain idempotent and accepted by Brevo.
        headers: input.idempotencyKey
          ? { "Idempotency-Key": this.toProviderIdempotencyKey(input.idempotencyKey) }
          : undefined,
        params: input.metadata,
      };

      const response = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          accept: "application/json",
          "api-key": this.apiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      if (response.ok) {
        const data = (await response.json().catch(() => ({}))) as { messageId?: string };
        const providerMessageId = data.messageId ? String(data.messageId) : `brevo_${Date.now()}`;
        return {
          accepted: true,
          status: "accepted",
          providerMessageId,
        };
      }

      const errorData = (await response.json().catch(() => ({}))) as { message?: string; code?: string };
      return {
        accepted: false,
        status: "rejected",
        errorCode: errorData.code ?? `http_${response.status}`,
        errorMessage: errorData.message ?? `Brevo API error ${response.status}`,
      };
    } catch (err) {
      return {
        accepted: false,
        status: "rejected",
        errorCode: "network_error",
        errorMessage: String(err),
      };
    }
  }

  verifyWebhookSignature(headers: Record<string, string>, rawBody: string): boolean {
    if (!this.webhookSecret) return false;

    // Brevo's current secured-webhook mechanism supports Bearer auth and
    // custom headers. Prefer those mechanisms in production.
    const authorization = headers.authorization || headers.Authorization || "";
    const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);
    if (bearerMatch?.[1] && this.constantTimeEqual(bearerMatch[1].trim(), this.webhookSecret)) {
      return true;
    }

    const customSecret = headers["x-ilipresto-webhook-secret"]
      || headers["X-Ilipresto-Webhook-Secret"]
      || headers["x-brevo-webhook-secret"]
      || headers["X-Brevo-Webhook-Secret"];
    if (customSecret && this.constantTimeEqual(customSecret.trim(), this.webhookSecret)) {
      return true;
    }

    // Transitional compatibility with the previously implemented HMAC
    // scheme. Existing manually configured hooks keep working while the
    // production webhook is migrated to Bearer authentication.
    const signature = headers["x-mailin-signature"] || headers["X-Mailin-Signature"];
    if (!signature) return false;

    try {
      const expectedHex = createHmac("sha256", this.webhookSecret).update(rawBody).digest("hex");
      const expectedB64 = Buffer.from(expectedHex, "hex").toString("base64");
      const normalized = signature.replace(/^sha256=/i, "").trim();
      return this.constantTimeEqual(normalized, expectedHex) || this.constantTimeEqual(normalized, expectedB64);
    } catch {
      return false;
    }
  }

  parseWebhook(raw: unknown): NormalizedWebhookEvent[] {
    const payloads = Array.isArray(raw) ? raw : [raw];
    const out: NormalizedWebhookEvent[] = [];

    for (let idx = 0; idx < payloads.length; idx += 1) {
      const item = payloads[idx];
      if (!item || typeof item !== "object") continue;
      const payload = item as Record<string, unknown>;
      const event = String(payload.event || payload.type || "sent").toLowerCase();

      const typeMap: Record<string, NormalizedWebhookEvent["type"]> = {
        sent: "sent",
        request: "sent",
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
        uniqueopened: "opened",
        click: "clicked",
        clicked: "clicked",
        unique_clicked: "clicked",
        unsubscribed: "unsubscribed",
      };

      const occurredAt = this.resolveEventTimestamp(payload);
      const messageId = payload["message-id"]
        ? String(payload["message-id"])
        : payload.messageId
          ? String(payload.messageId)
          : undefined;
      const recipient = payload.email ? String(payload.email).trim().toLowerCase() : undefined;
      const bounceKind = event === "hard_bounce" || event === "hardbounce"
        ? "hard" as const
        : event === "soft_bounce" || event === "softbounce"
          ? "soft" as const
          : undefined;

      // Brevo's payload `id` identifies the webhook configuration, not a
      // unique delivery event. Build a stable event key from message/event/time.
      const providerEventId = payload.event_id
        ? String(payload.event_id)
        : [messageId || `webhook-${String(payload.id ?? "unknown")}`, event, recipient || "", String(occurredAt), String(idx)].join(":");

      out.push({
        providerEventId,
        providerMessageId: messageId,
        type: typeMap[event] ?? "sent",
        bounceKind,
        recipient,
        occurredAt,
        raw: payload,
      });
    }

    return out;
  }

  private parseSender(from: string): { email: string; name?: string } {
    const m = from.match(/^(.*)<([^>]+)>$/);
    if (!m) return { email: from.trim() };
    const name = m[1]?.trim().replace(/^"|"$/g, "");
    const email = m[2]?.trim() || from.trim();
    return name ? { email, name } : { email };
  }

  private constantTimeEqual(a: string, b: string): boolean {
    const aBuf = Buffer.from(a, "utf8");
    const bBuf = Buffer.from(b, "utf8");
    if (aBuf.length !== bBuf.length) return false;
    return timingSafeEqual(aBuf, bBuf);
  }

  private toProviderIdempotencyKey(value: string): string {
    const normalized = String(value || "").trim();
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(normalized)) {
      return normalized;
    }

    const chars = createHash("sha256").update(normalized).digest("hex").slice(0, 32).split("");
    chars[12] = "5";
    chars[16] = ((parseInt(chars[16] || "0", 16) & 0x3) | 0x8).toString(16);
    const hex = chars.join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
  }

  private resolveEventTimestamp(payload: Record<string, unknown>): number {
    const timestampCandidates = [
      payload.ts_epoch,
      payload.ts_event,
      payload.ts,
      payload.timestamp,
      payload.date,
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
        if (!Number.isNaN(asDate)) return asDate;
      }
    }

    return Date.now();
  }
}
