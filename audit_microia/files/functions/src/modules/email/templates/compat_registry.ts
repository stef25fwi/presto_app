import { DefaultTemplateContent, TemplateCode, TemplateRegistryItem } from "../../../types/templates";
import {
  getDefaultTemplateContent as getLegacyDefaultTemplateContent,
  getTemplateMeta as getLegacyTemplateMeta,
  listMissingRequiredVariables as listLegacyMissingRequiredVariables,
  templateRegistry as legacyTemplateRegistry,
} from "./registry";
import { modularEmailTemplates } from "./definitions";

const modularTemplateByCode = new Map(
  modularEmailTemplates.map((template) => [template.templateCode as TemplateCode, template]),
);

function mapModularChannel(templateCode: TemplateCode): TemplateRegistryItem["channel"] {
  switch (templateCode) {
    case "tpl_lifecycle_profile_incomplete_reminder_v1":
    case "tpl_lifecycle_first_listing_not_published_v1":
    case "tpl_transactional_message_received_v2":
      return "produit";
    case "tpl_marketing_reactivation_30_days_v1":
    case "tpl_marketing_nearby_new_listings_v1":
      return "marketing";
    case "tpl_marketing_referral_invite_v1":
      return "transactionnel";
    default:
      return "transactionnel";
  }
}

function mapModularCategory(templateCode: TemplateCode): string {
  switch (templateCode) {
    case "tpl_transactional_account_welcome_v2":
    case "tpl_transactional_account_email_verification_v2":
    case "tpl_transactional_account_login_otp_v1":
    case "tpl_transactional_account_password_forgotten_v2":
    case "tpl_transactional_account_password_changed_v2":
    case "tpl_transactional_account_deletion_requested_v1":
    case "tpl_transactional_account_deleted_v1":
    case "tpl_lifecycle_account_verified_v1":
    case "tpl_lifecycle_profile_incomplete_reminder_v1":
      return "account_auth";
    case "tpl_transactional_listing_under_review_v2":
    case "tpl_transactional_listing_published_v2":
    case "tpl_transactional_listing_rejected_v2":
    case "tpl_lifecycle_first_listing_not_published_v1":
      return "listings";
    case "tpl_transactional_message_received_v2":
      return "messaging";
    case "tpl_transactional_payment_confirmed_v2":
    case "tpl_transactional_payment_failed_v2":
    case "tpl_transactional_subscription_renewed_v1":
    case "tpl_transactional_subscription_expired_v1":
      return "billing";
    case "tpl_marketing_nearby_new_listings_v1":
      return "saved_search";
    default:
      return "marketing";
  }
}

function mapModularPreferenceTopic(templateCode: TemplateCode): TemplateRegistryItem["preference_topic"] {
  switch (templateCode) {
    case "tpl_transactional_message_received_v2":
      return "messaging";
    case "tpl_transactional_listing_under_review_v2":
    case "tpl_transactional_listing_published_v2":
    case "tpl_transactional_listing_rejected_v2":
    case "tpl_lifecycle_first_listing_not_published_v1":
      return "listings";
    case "tpl_marketing_nearby_new_listings_v1":
      return "saved_search";
    default:
      return "other";
  }
}

const modularTemplateRegistry: TemplateRegistryItem[] = modularEmailTemplates.map((template) => ({
  template_code: template.templateCode as TemplateCode,
  channel: mapModularChannel(template.templateCode as TemplateCode),
  category: mapModularCategory(template.templateCode as TemplateCode),
  preference_topic: mapModularPreferenceTopic(template.templateCode as TemplateCode),
  required_variables: template.variables.filter((variable) => variable.required).map((variable) => variable.key),
  default_subject_fr: template.subject,
  default_preheader_fr: template.previewText,
}));

export const compatTemplateRegistry: TemplateRegistryItem[] = [
  ...legacyTemplateRegistry,
  ...modularTemplateRegistry,
];

export function getCompatTemplateMeta(templateCode: string): TemplateRegistryItem | null {
  return compatTemplateRegistry.find((item) => item.template_code === templateCode) || null;
}

export function listCompatMissingRequiredVariables(templateCode: string, payload: Record<string, unknown>): string[] {
  const modularTemplate = modularTemplateByCode.get(templateCode as TemplateCode);
  if (!modularTemplate) {
    return listLegacyMissingRequiredVariables(templateCode, payload);
  }

  return modularTemplate.variables
    .filter((variable) => variable.required)
    .map((variable) => variable.key)
    .filter((key) => {
      const value = payload[key];
      if (value === undefined || value === null) return true;
      if (typeof value === "string") return value.trim().length === 0;
      return false;
    });
}

export function getCompatDefaultTemplateContent(templateCode: TemplateCode, locale: "fr" | "en"): DefaultTemplateContent {
  const modularTemplate = modularTemplateByCode.get(templateCode);
  if (modularTemplate) {
    return {
      html: modularTemplate.html,
      text: modularTemplate.text,
    };
  }

  return getLegacyDefaultTemplateContent(templateCode, locale);
}