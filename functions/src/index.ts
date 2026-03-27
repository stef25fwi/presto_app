import { setGlobalOptions } from "firebase-functions/v2";
import { EMAIL_PROVIDER_SECRETS } from "./config/env";

setGlobalOptions({
  secrets: EMAIL_PROVIDER_SECRETS,
});

export { onUserCreated } from "./modules/auth/triggers";
export { requestPasswordResetEmail, requestEmailVerificationEmail, reportPasswordChanged, trackUserLogin } from "./modules/auth/callables";

export { onListingPublished, onOfferCreated, onOfferUpdated } from "./modules/listings/triggers";
export { enqueueExpiringListingEmails } from "./modules/listings/scheduled";
export { onLegalTermsSettingsUpdated, onLegalPrivacySettingsUpdated } from "./modules/legal/triggers";
export { enqueueMarketingOnboardingEmails } from "./modules/marketing/scheduled";
export { onNewsletterCampaignCreated, onNewsletterCampaignUpdated } from "./modules/marketing/triggers";

export { onConversationSubMessageCreated } from "./modules/messaging/triggers";
export { enqueueUnreadMessageReminders } from "./modules/messaging/scheduled";
export {
  ensureOfferConversation,
  sendConversationMessage,
  markConversationRead,
  archiveConversation,
  unarchiveConversation,
  blockConversation,
  unblockConversation,
} from "./modules/messaging/callables";
export { registerPushToken, unregisterPushToken } from "./modules/notifications/callables";
export { onNotificationCreated, onNotificationUpdated } from "./modules/notifications/triggers";

export { onSupportTicketCreated, onSupportTicketReplied } from "./modules/support/triggers";
export { onReportCreated, onReportUpdated } from "./modules/moderation/triggers";
export { onSubscriptionUpdated, onBillingInvoiceUpdated } from "./modules/billing/triggers";

export {
  enqueueEmailJobsFromEventTrigger,
  processEmailJobTrigger,
  processScheduledEmailDigests,
  retryFailedEmailJobs,
  cleanupExpiredEmailJobs,
} from "./modules/email/queue/triggers";

export { handleEmailProviderWebhook } from "./modules/email/webhooks/handler";

export { purgeOldEmailWebhooks, purgeOldEmailLogs, syncEmailAnalytics } from "./modules/email/scheduled";
