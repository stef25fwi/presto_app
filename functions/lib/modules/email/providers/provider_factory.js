"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createEmailProvider = createEmailProvider;
const env_1 = require("../../../config/env");
const provider_1 = require("../../../config/provider");
const brevo_provider_1 = require("./brevo_provider");
const resend_provider_1 = require("./resend_provider");
function hasValue(value) {
    return String(value || "").trim().length > 0;
}
function createEmailProvider() {
    const providerName = String((0, provider_1.getProviderName)() || "resend").toLowerCase();
    const brevoApiKey = env_1.BREVO_API_KEY.value();
    const brevoWebhookSecret = env_1.BREVO_WEBHOOK_SECRET.value();
    const resendApiKey = env_1.EMAIL_PROVIDER_API_KEY.value();
    const resendWebhookSecret = env_1.EMAIL_PROVIDER_WEBHOOK_SECRET.value();
    const hasBrevoConfig = hasValue(brevoApiKey) && hasValue(brevoWebhookSecret);
    const hasResendConfig = hasValue(resendApiKey) && hasValue(resendWebhookSecret);
    switch (providerName) {
        case "brevo": {
            if (!hasBrevoConfig) {
                throw new Error("Brevo provider selected but BREVO_API_KEY/BREVO_WEBHOOK_SECRET are not fully configured");
            }
            return new brevo_provider_1.BrevoProvider(brevoApiKey, brevoWebhookSecret);
        }
        case "resend": {
            if (!hasResendConfig) {
                throw new Error("Resend provider selected but EMAIL_PROVIDER_API_KEY/EMAIL_PROVIDER_WEBHOOK_SECRET are not fully configured");
            }
            return new resend_provider_1.ResendProvider(resendApiKey, resendWebhookSecret);
        }
        default:
            throw new Error(`Unsupported EMAIL_PROVIDER_NAME: ${providerName}`);
    }
}
//# sourceMappingURL=provider_factory.js.map