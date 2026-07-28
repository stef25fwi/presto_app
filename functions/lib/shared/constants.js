"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LISTING_VALIDATION = exports.EMAIL_RETRY_MINUTES = exports.READ_ONLY_LEGACY_COLLECTIONS = exports.LEGACY_COLLECTIONS = exports.COLLECTIONS = void 0;
exports.COLLECTIONS = {
    users: "users",
    listings: "listings",
    listingDrafts: "listingDrafts",
    listingPhotoReviews: "listingPhotoReviews",
    conversations: "conversations",
    favorites: "favorites",
    listingReports: "listingReports",
    messageReports: "messageReports",
    userModeration: "userModeration",
    reviews: "reviews",
    reviewReports: "review_reports",
    reviewReplies: "review_replies",
    notifications: "notifications",
    messages: "messages",
    listingModeration: "listingModeration",
    adminActions: "adminActions",
    categories: "categories",
    cities: "cities",
    analyticsSnapshots: "analyticsSnapshots",
    appConfig: "appConfig",
    newsletterCampaigns: "newsletter_campaigns",
    conversationMessages: "conversation_messages",
    savedSearches: "saved_searches",
    pros: "pros",
    supportTickets: "support_tickets",
    reports: "reports",
    subscriptions: "subscriptions",
    billingInvoices: "billing_invoices",
    notificationPreferences: "notification_preferences",
    pushTokens: "push_tokens",
    emailTemplates: "email_templates",
    emailTemplateVersions: "email_template_versions",
    emailEvents: "email_events",
    emailJobs: "email_jobs",
    emailLogs: "email_logs",
    emailSuppressions: "email_suppressions",
    emailBounces: "email_bounces",
    emailUnsubscribes: "email_unsubscribes",
    emailProviderWebhooks: "email_provider_webhooks",
    audits: "audits",
    systemSettings: "system_settings",
};
exports.LEGACY_COLLECTIONS = {
    offers: "offers",
    profiles: "profiles",
    userProfiles: "user_profiles",
    listingDrafts: "listing_drafts",
    chatThreads: "chatThreads",
};
exports.READ_ONLY_LEGACY_COLLECTIONS = exports.LEGACY_COLLECTIONS;
exports.EMAIL_RETRY_MINUTES = [1, 5, 20, 120, 480];
exports.LISTING_VALIDATION = {
    titleMinLength: 10,
    titleMaxLength: 120,
    descriptionMinLength: 30,
    descriptionMaxLength: 4000,
    maxMediaCount: 10,
};
//# sourceMappingURL=constants.js.map