"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LISTING_VALIDATION = exports.EMAIL_RETRY_MINUTES = exports.COLLECTIONS = void 0;
exports.COLLECTIONS = {
    users: "users",
    /** @deprecated use userProfiles */
    profiles: "profiles",
    userProfiles: "user_profiles",
    /** @deprecated use listings */
    offers: "offers",
    listings: "listings",
    /**
     * Collection active pour les brouillons d'annonces (Flutter: collection('listingDrafts')).
     * Attention : la clé s'appelle listingDraftsV2 mais la valeur Firestore est "listingDrafts".
     */
    listingDraftsV2: "listingDrafts",
    listingModeration: "listingModeration",
    listingReports: "listingReports",
    /** @deprecated Ancien système de messagerie — utiliser conversations */
    chatThreads: "chatThreads",
    adminActions: "adminActions",
    categories: "categories",
    cities: "cities",
    analyticsSnapshots: "analyticsSnapshots",
    appConfig: "appConfig",
    newsletterCampaigns: "newsletter_campaigns",
    /**
     * @deprecated Ancien emplacement de brouillons ("listing_drafts").
     * Les nouveaux brouillons sont dans listingDraftsV2 ("listingDrafts").
     */
    listingDrafts: "listing_drafts",
    conversations: "conversations",
    /**
     * Collection top-level non utilisée actuellement — les messages sont dans
     * la sous-collection conversations/{id}/messages.
     */
    conversationMessages: "conversation_messages",
    savedSearches: "saved_searches",
    favorites: "favorites",
    /** Profils professionnels — collection Flutter: 'pros' */
    pros: "pros",
    supportTickets: "support_tickets",
    reports: "reports",
    subscriptions: "subscriptions",
    billingInvoices: "billing_invoices",
    notifications: "notifications",
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
exports.EMAIL_RETRY_MINUTES = [1, 5, 20, 120, 480];
exports.LISTING_VALIDATION = {
    titleMinLength: 10,
    titleMaxLength: 120,
    descriptionMinLength: 30,
    descriptionMaxLength: 4000,
    maxMediaCount: 10,
};
//# sourceMappingURL=constants.js.map