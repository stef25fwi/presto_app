"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MODERATION_STATUS_TRANSITIONS = exports.LISTING_STATUS_TRANSITIONS = exports.LISTING_SERVER_ONLY_FIELDS = exports.MODERATION_ROLES = exports.ADMIN_ROLES = exports.RECAPTCHA_ACTIONS = exports.PRODUCT_ANALYTICS_EVENTS = exports.NOTIFICATION_TYPES = exports.CHAT_THREAD_STATUSES = exports.LISTING_VISIBILITIES = exports.MODERATION_AUTO_FLAGS = exports.MESSAGE_REPORT_REASON_CODES = exports.REPORT_REASON_CODES = exports.REPORT_STATUSES = exports.MODERATION_STATUSES = exports.LISTING_STATUSES = exports.USER_ROLES = void 0;
exports.hasRole = hasRole;
exports.isAdminRole = isAdminRole;
exports.isModerationRole = isModerationRole;
exports.canTransitionListingStatus = canTransitionListingStatus;
exports.canTransitionModerationStatus = canTransitionModerationStatus;
exports.USER_ROLES = ["user", "moderator", "admin", "superadmin", "pro"];
exports.LISTING_STATUSES = [
    "draft",
    "pending",
    "active",
    "rejected",
    "archived",
    "sold",
    "deleted",
];
exports.MODERATION_STATUSES = [
    "pending",
    "auto_flagged",
    "approved",
    "rejected",
    "manual_review",
    "blocked",
];
exports.REPORT_STATUSES = [
    "open",
    "under_review",
    "resolved",
    "dismissed",
];
exports.REPORT_REASON_CODES = [
    "spam",
    "fraud",
    "inappropriate",
    "duplicate",
    "wrong_category",
    "fake_listing",
    "harassment",
    "other",
];
exports.MESSAGE_REPORT_REASON_CODES = [
    "spam",
    "fraud",
    "harassment",
    "inappropriate",
    "other",
];
exports.MODERATION_AUTO_FLAGS = [
    "adult_content",
    "violent_content",
    "suspicious_text",
    "spam_pattern",
    "duplicate_listing",
    "too_many_posts",
    "risky_user",
    "banned_term",
    "report_threshold_exceeded",
];
exports.LISTING_VISIBILITIES = ["private", "public", "hidden"];
exports.CHAT_THREAD_STATUSES = ["open", "archived", "blocked", "closed"];
exports.NOTIFICATION_TYPES = [
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
];
exports.PRODUCT_ANALYTICS_EVENTS = [
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
];
exports.RECAPTCHA_ACTIONS = [
    "listing_submit",
    "listing_report",
    "message_create",
    "message_report",
    "account_create",
];
exports.ADMIN_ROLES = ["admin", "superadmin"];
exports.MODERATION_ROLES = ["moderator", "admin", "superadmin"];
exports.LISTING_SERVER_ONLY_FIELDS = [
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
];
exports.LISTING_STATUS_TRANSITIONS = {
    draft: ["pending", "deleted"],
    pending: ["active", "rejected", "archived", "deleted"],
    active: ["sold", "archived", "deleted"],
    rejected: ["draft", "deleted", "archived"],
    archived: ["active", "deleted"],
    sold: ["archived", "deleted"],
    deleted: [],
};
exports.MODERATION_STATUS_TRANSITIONS = {
    pending: ["approved", "auto_flagged", "manual_review", "rejected", "blocked"],
    auto_flagged: ["manual_review", "approved", "rejected", "blocked"],
    approved: ["manual_review", "blocked"],
    rejected: ["manual_review", "approved"],
    manual_review: ["approved", "rejected", "blocked"],
    blocked: ["manual_review"],
};
function hasRole(roles, expected) {
    return roles.includes(expected);
}
function isAdminRole(role) {
    return exports.ADMIN_ROLES.includes(role);
}
function isModerationRole(role) {
    return exports.MODERATION_ROLES.includes(role);
}
function canTransitionListingStatus(from, to) {
    return exports.LISTING_STATUS_TRANSITIONS[from].includes(to);
}
function canTransitionModerationStatus(from, to) {
    return exports.MODERATION_STATUS_TRANSITIONS[from].includes(to);
}
//# sourceMappingURL=enums.js.map