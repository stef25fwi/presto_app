export type EmailCategory =
  | "security"
  | "core_product"
  | "messaging"
  | "billing"
  | "business"
  | "growth";

export type EmailType = "transactional" | "lifecycle" | "marketing";

export type EmailTone =
  | "security"
  | "business"
  | "onboarding"
  | "growth"
  | "trust";

export type EmailTemplateId =
  | "verify_email"
  | "login_otp"
  | "forgot_password"
  | "password_changed"
  | "account_deletion_requested"
  | "account_deleted"
  | "welcome_user"
  | "profile_incomplete_reminder"
  | "account_verified"
  | "listing_under_review"
  | "listing_published"
  | "listing_rejected"
  | "message_received"
  | "payment_confirmed"
  | "payment_failed"
  | "subscription_renewed"
  | "subscription_expired"
  | "first_listing_not_published"
  | "reactivation_30_days"
  | "nearby_new_listings"
  | "referral_invite";

export type EmailEventName =
  | "user.email_verification.requested"
  | "user.otp.requested"
  | "user.password_reset.requested"
  | "user.password_changed"
  | "user.account.deletion.requested"
  | "user.account.deleted"
  | "user.created"
  | "profile.incomplete.reminder"
  | "profile.verified"
  | "listing.submitted"
  | "listing.published"
  | "listing.rejected"
  | "conversation.message_received"
  | "billing.payment.succeeded"
  | "billing.payment.failed"
  | "billing.subscription.renewed"
  | "billing.subscription.expired"
  | "listing.first_not_published.reminder"
  | "growth.reactivation.30_days"
  | "growth.nearby_new_listings"
  | "growth.referral_invite";

export type EmailVariableType =
  | "string"
  | "url"
  | "number"
  | "date"
  | "boolean"
  | "html";

export interface EmailVariableDefinition {
  key: string;
  type: EmailVariableType;
  required: boolean;
  description: string;
}

export interface EmailCallToAction {
  label: string;
  urlVariable: string;
  secondary?: boolean;
}

export interface EmailSendRules {
  trigger: EmailEventName;
  sendWhen: string;
  skipWhen: string[];
  unsubscribeAllowed: boolean;
  requiredPreferences: string[];
  idempotencyScope: string;
}

export interface EmailTemplateDefinition {
  id: EmailTemplateId;
  templateCode: string;
  category: EmailCategory;
  type: EmailType;
  tone: EmailTone;
  goal: string;
  event: EmailEventName;
  variables: EmailVariableDefinition[];
  subject: string;
  previewText: string;
  cta?: EmailCallToAction;
  secondaryCta?: EmailCallToAction;
  html: string;
  text: string;
  rules: EmailSendRules;
}

export interface EmailRecipient {
  userId?: string;
  email: string;
  firstName?: string;
  locale?: "fr" | "en";
  timezone?: string;
}

export interface EmailRenderResult {
  subject: string;
  previewText: string;
  html: string;
  text: string;
}

export interface EmailDispatchInput {
  templateId: EmailTemplateId;
  recipient: EmailRecipient;
  variables: Record<string, unknown>;
  force?: boolean;
  eventId?: string;
  idempotencyKey?: string;
  metadata?: Record<string, string>;
}

export interface EmailSendResult {
  accepted: boolean;
  provider: string;
  providerMessageId?: string;
  status: "accepted" | "rejected" | "skipped";
  errorCode?: string;
  errorMessage?: string;
}

export interface EmailLogRecord {
  eventType: EmailEventName;
  templateId: EmailTemplateId;
  templateCode: string;
  userId?: string | null;
  recipient: string;
  status: string;
  provider: string;
  providerMessageId?: string | null;
  createdAt: number;
  sentAt?: number;
  failedAt?: number;
  errorCode?: string;
  errorMessage?: string;
  metadata: Record<string, unknown>;
  locale: "fr" | "en";
  category: EmailCategory;
  type: EmailType;
  retryCount: number;
}

export interface CommunicationPreferences {
  locale: "fr" | "en";
  timezone: string;
  transactionalEmailEnabled: boolean;
  lifecycleEmailEnabled: boolean;
  marketingEmailEnabled: boolean;
  messageEmailEnabled: boolean;
  nearbyListingsEnabled: boolean;
  referralEnabled: boolean;
  unsubscribeToken?: string;
}