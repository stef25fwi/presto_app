export interface ProviderSendInput {
  to: string;
  from: string;
  subject: string;
  html: string;
  text: string;
  tags: string[];
  metadata: Record<string, string>;
  idempotencyKey: string;
  stream: "transactional" | "broadcast";
}

export interface ProviderSendResult {
  accepted: boolean;
  providerMessageId?: string;
  status: "accepted" | "rejected";
  errorCode?: string;
  errorMessage?: string;
}

export interface NormalizedWebhookEvent {
  providerEventId: string;
  providerMessageId?: string;
  type:
    | "sent"
    | "delivered"
    | "deferred"
    | "bounced"
    | "complained"
    | "opened"
    | "clicked"
    | "unsubscribed"
    | "dropped";
  /** Provider-specific bounce severity when type === "bounced". */
  bounceKind?: "soft" | "hard";
  recipient?: string;
  occurredAt: number;
  raw: unknown;
}

export interface EmailProvider {
  name(): string;
  send(input: ProviderSendInput): Promise<ProviderSendResult>;
  verifyWebhookSignature(headers: Record<string, string>, rawBody: string): boolean;
  parseWebhook(raw: unknown): NormalizedWebhookEvent[];
}
