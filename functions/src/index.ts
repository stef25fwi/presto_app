import { setGlobalOptions } from "firebase-functions/v2";
import { EMAIL_PROVIDER_SECRETS } from "./config/env";

setGlobalOptions({
  secrets: EMAIL_PROVIDER_SECRETS,
});

export { onUserCreated } from "./modules/auth/triggers";

export { onListingPublished } from "./modules/listings/triggers";
export { enqueueExpiringListingEmails } from "./modules/listings/scheduled";

export { onMessageCreated } from "./modules/messaging/triggers";
export { enqueueUnreadMessageReminders } from "./modules/messaging/scheduled";

export { onSupportTicketCreated, onSupportTicketReplied } from "./modules/support/triggers";
export { onReportCreated } from "./modules/moderation/triggers";
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
