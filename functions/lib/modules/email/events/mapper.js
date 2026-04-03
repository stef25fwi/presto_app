"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mapEventToTemplate = mapEventToTemplate;
function mapEventToTemplate(eventName) {
    switch (eventName) {
        // ── Compte & Auth ──────────────────────────────────────────────────────
        case "user.created":
            return "tpl_transactional_account_welcome_v2";
        case "user.email_verification.requested":
            return "tpl_transactional_account_email_verification_v2";
        case "user.otp.requested":
            return "tpl_transactional_account_login_otp_v1";
        case "user.password_reset.requested":
            return "tpl_transactional_account_password_forgotten_v2";
        case "user.password_changed":
            return "tpl_transactional_account_password_changed_v2";
        case "user.account.deletion.requested":
            return "tpl_transactional_account_deletion_requested_v1";
        case "user.account.deleted":
            return "tpl_transactional_account_deleted_v1";
        case "user.login.suspicious":
            return "tpl_transactional_account_suspicious_login_v1";
        case "profile.verified":
            return "tpl_lifecycle_account_verified_v1";
        case "profile.incomplete.reminder":
            return "tpl_lifecycle_profile_incomplete_reminder_v1";
        // ── Annonces ──────────────────────────────────────────────────────────
        case "listing.submitted":
            return "tpl_transactional_listing_under_review_v2";
        case "listing.published":
            return "tpl_transactional_listing_published_v2";
        case "listing.rejected":
            return "tpl_transactional_listing_rejected_v2";
        case "listing.expiring_soon":
            return "tpl_product_listing_expiring_soon_v1";
        case "listing.expired":
            return "tpl_transactional_listing_expired_v1";
        case "listing.first_not_published.reminder":
            return "tpl_lifecycle_first_listing_not_published_v1";
        // ── Messagerie ────────────────────────────────────────────────────────
        case "message.created.new_thread":
        case "message.created.existing_thread":
            return "tpl_transactional_message_received_v2";
        case "conversation.pending_reminder_due":
            return "tpl_product_messaging_pending_reminder_v1";
        // ── Recherches sauvegardées ───────────────────────────────────────────
        case "saved_search.match_found":
            return "tpl_product_saved_search_match_found_v1";
        case "saved_search.daily_digest.ready":
        case "saved_search.weekly_digest.ready":
            return "tpl_product_saved_search_match_found_v1";
        // ── Favoris ───────────────────────────────────────────────────────────
        case "favorite.listing.updated":
        case "favorite.listing.expired":
            return null; // notification in-app uniquement
        // ── Support ───────────────────────────────────────────────────────────
        case "support.ticket.created":
            return "tpl_transactional_support_ticket_created_v1";
        case "support.ticket.replied":
            return "tpl_transactional_support_reply_v1";
        // ── Modération ────────────────────────────────────────────────────────
        case "report.created":
            return "tpl_transactional_moderation_report_received_v1";
        case "report.resolved":
            return "tpl_transactional_moderation_report_resolved_v1";
        // ── Légal ─────────────────────────────────────────────────────────────
        case "legal.terms.updated":
            return "tpl_transactional_legal_terms_updated_v1";
        case "legal.privacy.updated":
            return "tpl_transactional_legal_privacy_updated_v1";
        // ── Marketing / Onboarding ─────────────────────────────────────────────
        case "marketing.onboarding.d1_due":
            return "tpl_marketing_onboarding_d1_v1";
        case "marketing.onboarding.d3_due":
            return "tpl_marketing_onboarding_d3_v1";
        case "marketing.onboarding.d7_due":
            return "tpl_marketing_onboarding_d7_v1";
        case "marketing.newsletter.monthly":
            return "tpl_marketing_newsletter_v1";
        // ── Abonnement & Facturation ──────────────────────────────────────────
        case "subscription.renewal.upcoming":
            return "tpl_transactional_subscription_renewal_upcoming_v1";
        case "billing.subscription.renewed":
            return "tpl_transactional_subscription_renewed_v1";
        case "billing.subscription.expired":
            return "tpl_transactional_subscription_expired_v1";
        case "billing.payment.succeeded":
            return "tpl_transactional_payment_confirmed_v2";
        case "billing.payment.failed":
            return "tpl_transactional_payment_failed_v2";
        // ── Growth ────────────────────────────────────────────────────────────
        case "growth.reactivation.30_days":
            return "tpl_marketing_reactivation_30_days_v1";
        case "growth.nearby_new_listings":
            return "tpl_marketing_nearby_new_listings_v1";
        case "growth.referral_invite":
            return "tpl_marketing_referral_invite_v1";
        default:
            return null;
    }
}
//# sourceMappingURL=mapper.js.map