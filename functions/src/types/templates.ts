export type TemplateCode =
  | "tpl_transactional_account_welcome_v1"
  | "tpl_transactional_account_welcome_v2"
  | "tpl_transactional_account_email_verification_v1"
  | "tpl_transactional_account_email_verification_v2"
  | "tpl_transactional_account_password_forgotten_v1"
  | "tpl_transactional_account_password_forgotten_v2"
  | "tpl_transactional_account_password_changed_v1"
  | "tpl_transactional_account_password_changed_v2"
  | "tpl_transactional_account_suspicious_login_v1"
  | "tpl_transactional_account_login_otp_v1"
  | "tpl_transactional_account_deletion_requested_v1"
  | "tpl_transactional_account_deleted_v1"
  | "tpl_lifecycle_account_verified_v1"
  | "tpl_lifecycle_profile_incomplete_reminder_v1"
  | "tpl_transactional_listing_submitted_v1"
  | "tpl_transactional_listing_under_review_v2"
  | "tpl_transactional_listing_published_v1"
  | "tpl_transactional_listing_published_v2"
  | "tpl_transactional_listing_rejected_v1"
  | "tpl_transactional_listing_rejected_v2"
  | "tpl_transactional_listing_expired_v1"
  | "tpl_product_listing_expiring_soon_v1"
  | "tpl_product_messaging_new_message_v1"
  | "tpl_transactional_message_received_v2"
  | "tpl_product_messaging_pending_reminder_v1"
  | "tpl_product_lead_received_v1"
  | "tpl_product_saved_search_match_found_v1"
  | "tpl_transactional_support_ticket_created_v1"
  | "tpl_transactional_support_reply_v1"
  | "tpl_transactional_moderation_report_received_v1"
  | "tpl_transactional_moderation_report_resolved_v1"
  | "tpl_transactional_legal_terms_updated_v1"
  | "tpl_transactional_legal_privacy_updated_v1"
  | "tpl_marketing_onboarding_d1_v1"
  | "tpl_marketing_onboarding_d3_v1"
  | "tpl_marketing_onboarding_d7_v1"
  | "tpl_marketing_newsletter_v1"
  | "tpl_lifecycle_first_listing_not_published_v1"
  | "tpl_marketing_reactivation_30_days_v1"
  | "tpl_marketing_nearby_new_listings_v1"
  | "tpl_marketing_referral_invite_v1"
  | "tpl_transactional_subscription_renewal_upcoming_v1"
  | "tpl_transactional_subscription_renewed_v1"
  | "tpl_transactional_subscription_expired_v1"
  | "tpl_transactional_billing_payment_succeeded_v1"
  | "tpl_transactional_billing_payment_failed_v1"
  | "tpl_transactional_payment_confirmed_v2"
  | "tpl_transactional_payment_failed_v2";

export interface TemplateRegistryItem {
  template_code: TemplateCode;
  channel: "transactionnel" | "produit" | "marketing";
  category: string;
  preference_topic?: "messaging" | "listings" | "saved_search" | "other";
  required_variables: string[];
  default_subject_fr: string;
  default_preheader_fr: string;
}

export interface DefaultTemplateContent {
  html: string;
  text: string;
}
