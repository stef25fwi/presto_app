export const USER_ROLES = ["user", "moderator", "admin", "superadmin", "pro"] as const;
export type UserRole = (typeof USER_ROLES)[number];

export const LISTING_STATUSES = [
  "draft",
  "pending",
  "active",
  "rejected",
  "archived",
  "sold",
  "deleted",
] as const;
export type ListingStatus = (typeof LISTING_STATUSES)[number];

export const MODERATION_STATUSES = [
  "pending",
  "auto_flagged",
  "approved",
  "rejected",
  "manual_review",
  "blocked",
] as const;
export type ModerationStatus = (typeof MODERATION_STATUSES)[number];

export const REPORT_STATUSES = [
  "open",
  "under_review",
  "resolved",
  "dismissed",
] as const;
export type ReportStatus = (typeof REPORT_STATUSES)[number];

export const REPORT_REASON_CODES = [
  "spam",
  "fraud",
  "inappropriate",
  "duplicate",
  "wrong_category",
  "fake_listing",
  "harassment",
  "other",
] as const;
export type ReportReasonCode = (typeof REPORT_REASON_CODES)[number];

export const MESSAGE_REPORT_REASON_CODES = [
  "spam",
  "fraud",
  "harassment",
  "inappropriate",
  "other",
] as const;
export type MessageReportReasonCode = (typeof MESSAGE_REPORT_REASON_CODES)[number];

export const MODERATION_AUTO_FLAGS = [
  "adult_content",
  "violent_content",
  "suspicious_text",
  "spam_pattern",
  "duplicate_listing",
  "too_many_posts",
  "risky_user",
  "banned_term",
  "report_threshold_exceeded",
] as const;
export type ModerationAutoFlag = (typeof MODERATION_AUTO_FLAGS)[number];

export const LISTING_VISIBILITIES = ["private", "public", "hidden"] as const;
export type ListingVisibility = (typeof LISTING_VISIBILITIES)[number];

export const CHAT_THREAD_STATUSES = ["open", "archived", "blocked", "closed"] as const;
export type ChatThreadStatus = (typeof CHAT_THREAD_STATUSES)[number];

export const NOTIFICATION_TYPES = [
  "listing_approved",
  "listing_rejected",
  "listing_reported",
  "listing_expiring",
  "listing_expired",
  "listing_sold",
  "listing_renewal_reminder",
  "new_chat_message",
  "manual_review_required",
  "message_reported",
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export const PRODUCT_ANALYTICS_EVENTS = [
  "listing_create_started",
  "listing_create_completed",
  "listing_submitted",
  "listing_published",
  "listing_rejected",
  "listing_view",
  "listing_favorite_added",
  "listing_favorite_removed",
  "listing_contact_clicked",
  "listing_message_started",
  "listing_reported",
  "message_reported",
  "search_performed",
  "search_result_clicked",
  "premium_upgrade_started",
  "premium_upgrade_completed",
] as const;
export type ProductAnalyticsEvent = (typeof PRODUCT_ANALYTICS_EVENTS)[number];

export const RECAPTCHA_ACTIONS = [
  "listing_submit",
  "listing_report",
  "message_create",
  "message_report",
  "account_create",
] as const;
export type RecaptchaAction = (typeof RECAPTCHA_ACTIONS)[number];

export const ADMIN_ROLES: readonly UserRole[] = ["admin", "superadmin"] as const;
export const MODERATION_ROLES: readonly UserRole[] = ["moderator", "admin", "superadmin"] as const;

export const LISTING_SERVER_ONLY_FIELDS = [
  "moderationStatus",
  "reportCount",
  "favoriteCount",
  "viewCount",
  "contactCount",
  "riskScore",
  "safeSearchResult",
  "reviewedAt",
  "reviewedBy",
  "publishedAt",
  "status",
  "visibility",
  "isBoosted",
  "boostExpiresAt",
] as const;

export const LISTING_STATUS_TRANSITIONS: Record<ListingStatus, readonly ListingStatus[]> = {
  draft: ["pending", "deleted"],
  pending: ["active", "rejected", "archived", "deleted"],
  active: ["sold", "archived", "deleted"],
  rejected: ["draft", "deleted", "archived"],
  archived: ["active", "deleted"],
  sold: ["archived", "deleted"],
  deleted: [],
};

export const MODERATION_STATUS_TRANSITIONS: Record<ModerationStatus, readonly ModerationStatus[]> = {
  pending: ["approved", "auto_flagged", "manual_review", "rejected", "blocked"],
  auto_flagged: ["manual_review", "approved", "rejected", "blocked"],
  approved: ["manual_review", "blocked"],
  rejected: ["manual_review", "approved"],
  manual_review: ["approved", "rejected", "blocked"],
  blocked: ["manual_review"],
};

export function hasRole(roles: readonly UserRole[], expected: UserRole): boolean {
  return roles.includes(expected);
}

export function isAdminRole(role: UserRole): boolean {
  return ADMIN_ROLES.includes(role);
}

export function isModerationRole(role: UserRole): boolean {
  return MODERATION_ROLES.includes(role);
}

export function canTransitionListingStatus(from: ListingStatus, to: ListingStatus): boolean {
  return LISTING_STATUS_TRANSITIONS[from].includes(to);
}

export function canTransitionModerationStatus(from: ModerationStatus, to: ModerationStatus): boolean {
  return MODERATION_STATUS_TRANSITIONS[from].includes(to);
}