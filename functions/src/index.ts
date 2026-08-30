import { setGlobalOptions } from "firebase-functions/v2";
import { EMAIL_PROVIDER_SECRETS, PROJECT_REGION } from "./config/env";

setGlobalOptions({
  region: PROJECT_REGION,
  secrets: EMAIL_PROVIDER_SECRETS,
});

export { onUserCreated, onUserUpdated } from "./modules/auth/triggers";
export { onAuthUserCreated } from "./modules/auth/on_auth_user_created";
export { onUserRolesChanged } from "./modules/auth/role_claims_sync";
export { requestAccountDeletion } from "./modules/auth/account_deletion";
export { syncMyEmailVerification } from "./modules/auth/email_verification_sync";
// Doit rester après syncMyEmailVerification : tools/apply_auth_client_hardening.mjs
// vérifie l'adjacence de ces deux exports pour rester idempotent, et réinsère un
// doublon si une ligne s'intercale.
export { confirmPhoneVerified } from "./modules/auth/phone_verification";
export { reservePhoneVerificationAttempt } from "./modules/auth/phone_verification";
export {
  placesAutocomplete,
  placesDetails,
  adminGetAccessStatus,
  getMyAdminAccessStatus,
  adminGetUserStats,
  getUserPresenceStatus,
  microIaProcessAudio,
  adminGetMicroIaConfig,
  adminSetMicroIaConfig,
} from "./legacy/callables_compat";
export {
  generateOfferDraft,
  openAiExtractListingFields,
  openAiTranscribeListingAudio,
  openAiExtractListingFieldsFromAudio,
} from "./modules/ai/callables";
export { microIaProcessAudioV2 } from "./modules/ai/micro_ia_callable";
export { adminGetAiMetrics } from "./modules/ai/ai_metrics";
export {
  purgeExpiredAiAudio,
  purgeExpiredAiOperationalData,
} from "./modules/ai/operational_cleanup";
export {
  requestPasswordResetEmail,
  requestEmailVerificationEmail,
  requestLoginOtpEmail,
  reportPasswordChanged,
  trackUserLogin,
} from "./modules/auth/callables";

export { onListingPublished, onOfferCreated, onOfferUpdated } from "./modules/listings/triggers";
export { enqueueExpiringListingEmails, enqueueFirstListingNotPublishedReminders, enqueueFourHourExpiryPushNotifications } from "./modules/listings/scheduled";
export {
  createListingDraft,
  updateListingDraftMedia,
  submitListingDraft,
  incrementListingView,
  getListingContactPhone,
  deleteListing,
  closeOfferWithReason,
} from "./modules/marketplace/callables/listings";
export { adminBulkDeleteListings } from "./modules/marketplace/callables/admin_bulk_listings";
export { processOfferPhoto } from "./modules/marketplace/callables/media";
export { classifyServicePhoto } from "./modules/marketplace/callables/classify_service_photo";
export { reportListing, reportConversationMessage } from "./modules/marketplace/callables/reports";
export { exportMyData } from "./modules/marketplace/callables/account_data_export";
export {
  getEligibleRespondersForReview,
  submitVerifiedReview,
  getUserTrustScore,
  reportReview,
  replyToReview,
} from "./modules/marketplace/callables/reviews";
export {
  submitMutualVerifiedReview,
  getUserTrustScoreV2,
  reportReviewV2,
  replyToReviewV2,
  publishMaturedReviewsV2,
} from "./modules/marketplace/callables/reviews_v2";
export {
  getEligibleRespondersForReviewV2,
  getPendingReviewTasksV2,
  submitMutualVerifiedReviewComplete,
  reviseReviewV2,
  dismissPendingReviewTaskV2,
  getUserTrustScoreV2Complete,
} from "./modules/marketplace/callables/reviews_flow_v2";
export { adminModerateReviewV2 } from "./modules/marketplace/callables/reviews_admin_v2";
export { toggleFavorite } from "./modules/marketplace/callables/favorites";
export {
  createChatThreadFromListing,
  sendChatMessage,
} from "./modules/marketplace/callables/chat";
export {
  applyUserRoleClaims,
  logAdminAction,
  reviewListingPhoto,
} from "./modules/marketplace/callables/admin";
export {
  notifyListingApproved,
  notifyListingRejected,
} from "./modules/marketplace/triggers/notifications";
export {
  expireOldListings,
  publishApprovedListings,
} from "./modules/marketplace/scheduled/listings";
export { purgeOrphanedStorageFiles, purgeAbandonedListingDrafts } from "./modules/marketplace/scheduled/storage_cleanup";
export { onLegalTermsSettingsUpdated, onLegalPrivacySettingsUpdated } from "./modules/legal/triggers";
export { getPublicLegalConfig } from "./modules/legal/public_legal_config";
export {
  enqueueMarketingOnboardingEmails,
  enqueueNearbyNewListingsEmails,
  enqueueProfileIncompleteReminderEmails,
  enqueueReactivation30DaysEmails,
} from "./modules/marketing/scheduled";
export { sendReferralInviteEmail } from "./modules/marketing/callables";
export { onNewsletterCampaignCreated, onNewsletterCampaignUpdated } from "./modules/marketing/triggers";

export { onConversationSubMessageCreated } from "./modules/messaging/triggers";
export {
  onAgentAuthorizationRequested,
  onAgentAuthorizationDecision,
} from "./modules/agents/authorization_messaging";
export { enqueueUnreadMessageReminders, syncMessagingAnalytics } from "./modules/messaging/scheduled";
export {
  ensureOfferConversation,
  sendConversationMessage,
  markConversationRead,
  archiveConversation,
  unarchiveConversation,
  blockConversation,
  unblockConversation,
  adminUnblockConversation,
  deleteConversation,
  deleteConversationMessage,
  processConversationAttachmentPhoto,
} from "./modules/messaging/callables";
export { registerPushToken, unregisterPushToken, broadcastTestNotification, sendSelfTestNotification } from "./modules/notifications/callables";
export { onNotificationCreated, onNotificationUpdated } from "./modules/notifications/triggers";
export { reportClientMonitoringEvent } from "./modules/monitoring/callables";
export {
  collectWebVitals,
  aggregateWebVitals28Days,
  purgeExpiredWebVitals,
} from "./modules/monitoring/web_vitals";

export { onSupportTicketCreated, onSupportTicketReplied } from "./modules/support/triggers";
export { onReportCreated, onReportUpdated } from "./modules/moderation/triggers";
export { moderateNewOffer } from "./modules/moderation/moderate_new_offer";
export {
  generatePaymentInfoAudio,
  generatePaymentInfoAudioDraft,
  publishPaymentInfoAudioDraft,
} from "./modules/admin/payment_info_audio";
export {
  adminGenerateVideo,
  adminListGeneratedVideos,
  adminDeleteGeneratedVideo,
} from "./modules/admin/videomaker";
export { onSubscriptionUpdated, onBillingInvoiceUpdated } from "./modules/billing/triggers";
export {
  guardedCreateSubscriptionCheckoutSession as createSubscriptionCheckoutSession,
} from "./modules/billing/guarded_callables";
export {
  getSubscriptionCheckoutStatus,
  createSubscriptionPortalSession,
  auditStripeCatalog,
} from "./modules/billing/callables";

/*
Compatibility markers for the idempotent Stripe hardening generators. The real
Checkout export above intentionally goes through guarded_callables.

  createSubscriptionCheckoutSession,
  createSubscriptionPortalSession,
  auditStripeCatalog,
} from "./modules/billing/callables";

  createSubscriptionCheckoutSession,
  getSubscriptionCheckoutStatus,
  createSubscriptionPortalSession,
  auditStripeCatalog,
} from "./modules/billing/callables";
*/

export {
  getMySubscriptionCredits,
  consumeSubscriptionCredit,
  refundSubscriptionCredit,
  saveMyJourney,
  deleteMyJourney,
  listMyJourneys,
} from "./modules/billing/subscription_credits";
export { handleStripeWebhook } from "./modules/billing/stripe_webhook";
export { reconcileStripeSubscriptions } from "./modules/billing/reconciliation";

export {
  enqueueEmailJobsFromEventTrigger,
  processEmailJobTrigger,
  processScheduledEmailDigests,
  retryFailedEmailJobs,
  cleanupExpiredEmailJobs,
} from "./modules/email/queue/triggers";

export { handleEmailProviderWebhook } from "./modules/email/webhooks/handler";
export {
  handleInboundContactEmailWebhook,
  adminGetInboundMailboxSummary,
  adminListInboundEmails,
  adminMarkInboundEmailRead,
} from "./modules/email/inbound_contact";

export { purgeOldEmailWebhooks, purgeOldEmailLogs, syncEmailAnalytics } from "./modules/email/scheduled";

export { verifySiret } from "./modules/pro/verifySiret";
export { preVerifySiret } from "./modules/pro/preVerifySiret";
export { publicMarketplaceSeo } from "./modules/seo/public_marketplace";
