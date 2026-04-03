export type EventName =
  | "user.created"
  | "user.email_verification.requested"
  | "user.otp.requested"
  | "user.password_reset.requested"
  | "user.password_changed"
  | "user.account.deletion.requested"
  | "user.account.deleted"
  | "user.login.suspicious"
  | "profile.verified"
  | "profile.incomplete.reminder"
  | "listing.submitted"
  | "listing.published"
  | "listing.rejected"
  | "listing.expiring_soon"
  | "listing.expired"
  | "listing.first_not_published.reminder"
  | "message.created.new_thread"
  | "message.created.existing_thread"
  | "conversation.pending_reminder_due"
  | "saved_search.match_found"
  | "saved_search.daily_digest.ready"
  | "saved_search.weekly_digest.ready"
  | "favorite.listing.updated"
  | "favorite.listing.expired"
  | "support.ticket.created"
  | "support.ticket.replied"
  | "report.created"
  | "report.resolved"
  | "legal.terms.updated"
  | "legal.privacy.updated"
  | "marketing.onboarding.d1_due"
  | "marketing.onboarding.d3_due"
  | "marketing.onboarding.d7_due"
  | "marketing.newsletter.monthly"
  | "subscription.renewal.upcoming"
  | "billing.subscription.renewed"
  | "billing.subscription.expired"
  | "billing.payment.succeeded"
  | "billing.payment.failed"
  | "growth.reactivation.30_days"
  | "growth.nearby_new_listings"
  | "growth.referral_invite";

export interface DomainEventPayload {
  event_id: string;
  event_name: EventName;
  source_collection: string;
  source_id: string;
  actor_user_id?: string;
  recipient_user_id?: string;
  dedupe_key: string;
  occurred_at: number;
  payload: Record<string, unknown>;
}
