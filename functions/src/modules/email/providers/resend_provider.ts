import { EmailProvider, NormalizedWebhookEvent, ProviderSendInput, ProviderSendResult } from "./email_provider.interface";

export class ResendProvider implements EmailProvider {
  constructor(
    private readonly apiKey: string,
    private readonly webhookSecret: string,
  ) {}

  name(): string {
    return "resend";
  }

  async send(input: ProviderSendInput): Promise<ProviderSendResult> {
    if (!this.apiKey) {
      return {
        accepted: false,
        status: "rejected",
        errorCode: "provider_api_key_missing",
        errorMessage: "EMAIL_PROVIDER_API_KEY is not configured",
      };
    }

    try {
      const body = {
        from: input.from,
        to: Array.isArray(input.to) ? input.to : [input.to],
        subject: input.subject,
        html: input.html,
        text: input.text,
        tags: input.tags?.map((t) => ({ name: t, value: "1" })),
        headers: input.idempotencyKey
          ? { "Idempotency-Key": input.idempotencyKey }
          : undefined,
      };

      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      if (response.ok) {
        const data = (await response.json()) as { id?: string };
        return {
          accepted: true,
          status: "accepted",
          providerMessageId: data.id ?? `resend_${Date.now()}`,
        };
      }

      const errorData = (await response.json().catch(() => ({}))) as { message?: string; name?: string };
      return {
        accepted: false,
        status: "rejected",
        errorCode: errorData.name ?? `http_${response.status}`,
        errorMessage: errorData.message ?? `Resend API error ${response.status}`,
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
    const sig = headers["svix-signature"] || headers["Svix-Signature"];
    if (!sig) return false;

    // Svix signature verification (Resend uses Svix for webhooks)
    // Format: "v1,<base64-signature>"
    const msgId = headers["svix-id"] || headers["Svix-Id"];
    const msgTimestamp = headers["svix-timestamp"] || headers["Svix-Timestamp"];
    if (!msgId || !msgTimestamp) return false;

    try {
      const crypto = require("crypto") as typeof import("crypto");
      const toSign = `${msgId}.${msgTimestamp}.${rawBody}`;
      const secretBytes = Buffer.from(this.webhookSecret.replace(/^whsec_/, ""), "base64");
      const expected = crypto.createHmac("sha256", secretBytes).update(toSign).digest("base64");
      return sig.split(" ").some((s: string) => {
        const parts = s.split(",");
        return parts.length === 2 && parts[1] === expected;
      });
    } catch {
      return false;
    }
  }

  parseWebhook(raw: unknown): NormalizedWebhookEvent[] {
    if (!raw || typeof raw !== "object") return [];
    const payload = raw as Record<string, unknown>;
    const eventType = String(payload.type ?? "email.sent");

    const typeMap: Record<string, NormalizedWebhookEvent["type"]> = {
      "email.sent": "sent",
      "email.delivered": "delivered",
      "email.delivery_delayed": "deferred",
      "email.bounced": "bounced",
      "email.complained": "complained",
      "email.opened": "opened",
      "email.clicked": "clicked",
    };

    const data = (payload.data ?? {}) as Record<string, unknown>;
    return [
      {
        providerEventId: String(payload.id ?? `evt_${Date.now()}`),
        providerMessageId: data.email_id ? String(data.email_id) : undefined,
        type: typeMap[eventType] ?? "sent",
        recipient: data.to ? String(data.to) : undefined,
        occurredAt: Date.now(),
        raw,
      },
    ];
  }
}
