import { setGlobalOptions } from "firebase-functions/v2";
import { EMAIL_PROVIDER_SECRETS, PROJECT_REGION } from "./config/env";

setGlobalOptions({
  region: PROJECT_REGION,
  secrets: EMAIL_PROVIDER_SECRETS,
});

export { onUserCreated, onUserUpdated } from "./modules/auth/triggers";
export { onAuthUserCreated } from "./modules/auth/on_auth_user_created";
export {
  placesAutocomplete,
  placesDetails,
  generateOfferDraft,
  openAiExtractListingFields,
  openAiTranscribeListingAudio,
  openAiExtractListingFieldsFromAudio,
  adminGetAccessStatus,
  getMyAdminAccessStatus,
  adminGetUserStats,
  getUserPresenceStatus,
  microIaProcessAudio,
  adminGetMicroIaConfig,
  adminSetMicroIaConfig,
} from "./legacy/callables_compat";
export {
  requestPasswordResetEmail,
  requestEmailVerificationEmail,
  requestLoginOtpEmail,
  reportPasswordChanged,
  trackUserLogin,
} from "./modules/auth/callables";

export { onListingPublished, onOfferCreated, onOfferUpdated } from "./modules/listings/triggers";
export { enqueueExpiringListingEmails, enqueueFirstListingNotPublishedReminders } from "./modules/listings/scheduled";
export {
  submitListingDraft,
  incrementListingView,
  deleteListing,
} from "./modules/marketplace/callables/listings";
export { processOfferPhoto } from "./modules/marketplace/callables/media";
export { reportListing } from "./modules/marketplace/callables/reports";
export { toggleFavorite } from "./modules/marketplace/callables/favorites";
export {
  createChatThreadFromListing,
  sendChatMessage,
} from "./modules/marketplace/callables/chat";
export {
  applyUserRoleClaims,
  logAdminAction,
} from "./modules/marketplace/callables/admin";
export {
  notifyListingApproved,
  notifyListingRejected,
} from "./modules/marketplace/triggers/notifications";
export {
  expireOldListings,
  publishApprovedListings,
} from "./modules/marketplace/scheduled/listings";
export { onLegalTermsSettingsUpdated, onLegalPrivacySettingsUpdated } from "./modules/legal/triggers";
export {
  enqueueMarketingOnboardingEmails,
  enqueueNearbyNewListingsEmails,
  enqueueProfileIncompleteReminderEmails,
  enqueueReactivation30DaysEmails,
} from "./modules/marketing/scheduled";
export { sendReferralInviteEmail } from "./modules/marketing/callables";
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
  deleteConversation,
  deleteConversationMessage,
} from "./modules/messaging/callables";
export { registerPushToken, unregisterPushToken } from "./modules/notifications/callables";
export { onNotificationCreated, onNotificationUpdated } from "./modules/notifications/triggers";

export { onSupportTicketCreated, onSupportTicketReplied } from "./modules/support/triggers";
export { onReportCreated, onReportUpdated } from "./modules/moderation/triggers";
export { moderateNewOffer } from "./modules/moderation/moderate_new_offer";
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
