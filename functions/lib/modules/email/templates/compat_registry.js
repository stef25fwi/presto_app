"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.compatTemplateRegistry = void 0;
exports.getCompatTemplateMeta = getCompatTemplateMeta;
exports.listCompatMissingRequiredVariables = listCompatMissingRequiredVariables;
exports.getCompatDefaultTemplateContent = getCompatDefaultTemplateContent;
const registry_1 = require("./registry");
const definitions_1 = require("./definitions");
const modularTemplateByCode = new Map(definitions_1.modularEmailTemplates.map((template) => [template.templateCode, template]));
function mapModularChannel(templateCode) {
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
function mapModularCategory(templateCode) {
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
function mapModularPreferenceTopic(templateCode) {
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
const modularTemplateRegistry = definitions_1.modularEmailTemplates.map((template) => ({
    template_code: template.templateCode,
    channel: mapModularChannel(template.templateCode),
    category: mapModularCategory(template.templateCode),
    preference_topic: mapModularPreferenceTopic(template.templateCode),
    required_variables: template.variables.filter((variable) => variable.required).map((variable) => variable.key),
    default_subject_fr: template.subject,
    default_preheader_fr: template.previewText,
}));
exports.compatTemplateRegistry = [
    ...registry_1.templateRegistry,
    ...modularTemplateRegistry,
];
function getCompatTemplateMeta(templateCode) {
    return exports.compatTemplateRegistry.find((item) => item.template_code === templateCode) || null;
}
function listCompatMissingRequiredVariables(templateCode, payload) {
    const modularTemplate = modularTemplateByCode.get(templateCode);
    if (!modularTemplate) {
        return (0, registry_1.listMissingRequiredVariables)(templateCode, payload);
    }
    return modularTemplate.variables
        .filter((variable) => variable.required)
        .map((variable) => variable.key)
        .filter((key) => {
        const value = payload[key];
        if (value === undefined || value === null)
            return true;
        if (typeof value === "string")
            return value.trim().length === 0;
        return false;
    });
}
function getCompatDefaultTemplateContent(templateCode, locale) {
    const modularTemplate = modularTemplateByCode.get(templateCode);
    if (modularTemplate) {
        return {
            html: modularTemplate.html,
            text: modularTemplate.text,
        };
    }
    return (0, registry_1.getDefaultTemplateContent)(templateCode, locale);
}
//# sourceMappingURL=compat_registry.js.map