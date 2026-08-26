export type TimestampMs = number;

export type Channel = "transactionnel" | "produit" | "marketing";
export type JobPriority = "high" | "normal" | "low";
export type JobStatus =
  | "queued"
  | "scheduled"
  | "processing"
  | "sent"
  | "delivered"
  | "failed"
  | "dead_letter"
  | "cancelled";

export interface User {
  user_id: string;
  email: string;
  email_verified: boolean;
  status: "active" | "locked" | "restricted" | "banned" | "deleted";
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface NotificationPreferences {
  user_id: string;
  locale: "fr" | "en";
  timezone: string;
  quiet_hours: {
    enabled: boolean;
    start_local: string;
    end_local: string;
  };
  email: {
    account: { enabled: boolean };
    messaging: { mode: "immediate" | "digest_daily" | "digest_weekly" | "off" };
    listings: { mode: "immediate" | "digest_daily" | "digest_weekly" | "off" };
    saved_searches: { mode: "instant" | "daily" | "weekly" | "off" };
    favorites: { enabled: boolean };
    support: { enabled: boolean };
    marketing: { enabled: boolean; frequency_cap_per_week: number };
  };
  updated_at: TimestampMs;
}

export interface Listing {
  listing_id: string;
  owner_id: string;
  title: string;
  description: string;
  category: string;
  city: string;
  status:
    | "draft"
    | "submitted"
    | "in_moderation"
    | "published"
    | "paused"
    | "expired"
    | "rejected"
    | "hidden"
    | "deleted";
  price?: number;
  published_at?: TimestampMs;
  expires_at?: TimestampMs;
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface Conversation {
  conversation_id: string;
  participant_ids: string[];
  listing_id?: string;
  status: "open" | "archived" | "closed";
  last_message_at: TimestampMs;
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface ConversationMessage {
  message_id: string;
  conversation_id: string;
  sender_id: string;
  recipient_id: string;
  body: string;
  created_at: TimestampMs;
}

export interface EmailTemplate {
  template_code: string;
  channel: Channel;
  category: string;
  active_version: number;
  status: "active" | "inactive" | "deprecated";
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface EmailEvent {
  event_id: string;
  event_name: string;
  source_collection: string;
  source_id: string;
  payload: Record<string, unknown>;
  dedupe_key: string;
  occurred_at: TimestampMs;
  status: "created" | "enriched" | "jobs_created" | "ignored";
}

export interface EmailJob {
  job_id: string;
  event_id: string;
  recipient_user_id?: string;
  recipient_email: string;
  /** Origine canari de certification (voir queue/enqueue.ts) : exclut ce job des mesures de délivrabilité production. */
  is_certification?: boolean;
  channel: Channel;
  template_code: string;
  template_version: number;
  locale: "fr" | "en";
  priority: JobPriority;
  status: JobStatus;
  send_at: TimestampMs;
  expires_at: TimestampMs;
  attempts: number;
  max_attempts: number;
  idempotency_key: string;
  payload_hash: string;
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface EmailLog {
  log_id: string;
  job_id: string;
  provider: string;
  provider_message_id?: string;
  status:
    | "accepted"
    | "sent"
    | "delivered"
    | "deferred"
    | "bounced"
    | "complained"
    | "failed"
    | "opened"
    | "clicked"
    | "dropped"
    | "unsubscribed";
  error_code?: string;
  error_message?: string;
  created_at: TimestampMs;
}

export interface EmailBounce {
  bounce_id: string;
  email: string;
  bounce_type: "hard" | "soft";
  hard: boolean;
  reason?: string;
  occurred_at: TimestampMs;
}

export interface EmailSuppression {
  suppression_id: string;
  email: string;
  reason: "hard_bounce" | "complaint" | "manual" | "unsubscribe_all";
  source: "provider_webhook" | "admin" | "user_action" | "system";
  active: boolean;
  created_at: TimestampMs;
  expires_at?: TimestampMs;
}

export interface SavedSearch {
  search_id: string;
  user_id: string;
  query: string;
  frequency: "instant" | "daily" | "weekly" | "off";
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface SupportTicket {
  ticket_id: string;
  user_id: string;
  subject: string;
  status: "open" | "waiting_user" | "waiting_support" | "closed";
  priority: "low" | "normal" | "high";
  created_at: TimestampMs;
  updated_at: TimestampMs;
}

export interface Report {
  report_id: string;
  reporter_id: string;
  target_type: "listing" | "conversation" | "user";
  target_id: string;
  reason_code: string;
  status: "open" | "in_review" | "resolved" | "rejected";
  created_at: TimestampMs;
  resolved_at?: TimestampMs;
}
