"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createEmailProvider = createEmailProvider;
const env_1 = require("../../../config/env");
const provider_1 = require("../../../config/provider");
const resend_provider_1 = require("./resend_provider");
function createEmailProvider() {
    const providerName = (0, provider_1.getProviderName)();
    const apiKey = env_1.EMAIL_PROVIDER_API_KEY.value();
    const webhookSecret = env_1.EMAIL_PROVIDER_WEBHOOK_SECRET.value();
    switch (providerName) {
        case "resend":
        default:
            return new resend_provider_1.ResendProvider(apiKey, webhookSecret);
    }
}
//# sourceMappingURL=provider_factory.js.map