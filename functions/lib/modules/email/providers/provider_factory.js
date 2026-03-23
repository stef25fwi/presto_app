"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createEmailProvider = createEmailProvider;
const env_1 = require("../../../config/env");
const provider_1 = require("../../../config/provider");
const brevo_provider_1 = require("./brevo_provider");
const resend_provider_1 = require("./resend_provider");
function createEmailProvider() {
    const providerName = String((0, provider_1.getProviderName)() || "resend").toLowerCase();
    switch (providerName) {
        case "brevo": {
            const apiKey = env_1.BREVO_API_KEY.value() || env_1.EMAIL_PROVIDER_API_KEY.value();
            const webhookSecret = env_1.BREVO_WEBHOOK_SECRET.value() || env_1.EMAIL_PROVIDER_WEBHOOK_SECRET.value();
            return new brevo_provider_1.BrevoProvider(apiKey, webhookSecret);
        }
        case "resend": {
            const apiKey = env_1.EMAIL_PROVIDER_API_KEY.value() || env_1.BREVO_API_KEY.value();
            const webhookSecret = env_1.EMAIL_PROVIDER_WEBHOOK_SECRET.value() || env_1.BREVO_WEBHOOK_SECRET.value();
            return new resend_provider_1.ResendProvider(apiKey, webhookSecret);
        }
        default:
            throw new Error(`Unsupported EMAIL_PROVIDER_NAME: ${providerName}`);
    }
}
//# sourceMappingURL=provider_factory.js.map