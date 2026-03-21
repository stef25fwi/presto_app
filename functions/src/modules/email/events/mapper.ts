import { EventName } from "../../../types/events";
import { TemplateCode } from "../../../types/templates";

export function mapEventToTemplate(eventName: EventName): TemplateCode | null {
  switch (eventName) {
    // ── Compte & Auth ──────────────────────────────────────────────────────
    case "user.created":
      return "tpl_transactional_account_welcome_v1";
    case "user.email_verification.requested":
      return "tpl_transactional_account_email_verification_v1";
    case "user.password_reset.requested":
      return "tpl_transactional_account_password_forgotten_v1";
    case "user.password_changed":
      return "tpl_transactional_account_password_changed_v1";
    case "user.login.suspicious":
      return "tpl_transactional_account_suspicious_login_v1";

    // ── Annonces ──────────────────────────────────────────────────────────
    case "listing.submitted":
      return "tpl_transactional_listing_submitted_v1";
    case "listing.published":
      return "tpl_transactional_listing_published_v1";
    case "listing.rejected":
      return "tpl_transactional_listing_rejected_v1";
    case "listing.expiring_soon":
      return "tpl_product_listing_expiring_soon_v1";
    case "listing.expired":
      return null; // pas d'email pour l'expiration finale

    // ── Messagerie ────────────────────────────────────────────────────────
    case "message.created.new_thread":
    case "message.created.existing_thread":
      return "tpl_product_messaging_new_message_v1";
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
      return null; // pas d'email de fermeture de signalement

    // ── Légal ─────────────────────────────────────────────────────────────
    case "legal.terms.updated":
      return "tpl_transactional_legal_terms_updated_v1";
    case "legal.privacy.updated":
      return null; // couvert par les CGU

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
    case "billing.payment.failed":
      return "tpl_transactional_billing_payment_failed_v1";

    default:
      return null;
  }
}
