export type TemplateCode =
  | "tpl_transactional_account_welcome_v1"
  | "tpl_transactional_account_email_verification_v1"
  | "tpl_transactional_account_password_forgotten_v1"
  | "tpl_transactional_account_password_changed_v1"
  | "tpl_transactional_account_suspicious_login_v1"
  | "tpl_transactional_listing_submitted_v1"
  | "tpl_transactional_listing_published_v1"
  | "tpl_transactional_listing_rejected_v1"
  | "tpl_product_listing_expiring_soon_v1"
  | "tpl_product_messaging_new_message_v1"
  | "tpl_product_messaging_pending_reminder_v1"
  | "tpl_product_lead_received_v1"
  | "tpl_product_saved_search_match_found_v1"
  | "tpl_transactional_support_ticket_created_v1"
  | "tpl_transactional_support_reply_v1"
  | "tpl_transactional_moderation_report_received_v1"
  | "tpl_transactional_legal_terms_updated_v1"
  | "tpl_marketing_onboarding_d1_v1"
  | "tpl_marketing_onboarding_d3_v1"
  | "tpl_marketing_onboarding_d7_v1"
  | "tpl_marketing_newsletter_v1"
  | "tpl_transactional_subscription_renewal_upcoming_v1"
  | "tpl_transactional_billing_payment_failed_v1";

export interface TemplateRegistryItem {
  template_code: TemplateCode;
  channel: "transactionnel" | "produit" | "marketing";
  category: string;
  required_variables: string[];
  default_subject_fr: string;
  default_preheader_fr: string;
}

export interface DefaultTemplateContent {
  html: string;
  text: string;
}
