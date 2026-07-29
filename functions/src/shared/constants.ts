export const COLLECTIONS = {
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
} as const;

export const LEGACY_COLLECTIONS = {
  offers: "offers",
  profiles: "profiles",
  userProfiles: "user_profiles",
  listingDrafts: "listing_drafts",
  chatThreads: "chatThreads",
} as const;

export const READ_ONLY_LEGACY_COLLECTIONS = LEGACY_COLLECTIONS;

export const EMAIL_RETRY_MINUTES = [1, 5, 20, 120, 480];

export const LISTING_VALIDATION = {
  titleMinLength: 10,
  titleMaxLength: 120,
  descriptionMinLength: 30,
  descriptionMaxLength: 4000,
  maxMediaCount: 10,
} as const;
