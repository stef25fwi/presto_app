"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProviderName = getProviderName;
const env_1 = require("./env");
function getProviderName() {
    const explicit = String(env_1.EMAIL_PROVIDER_NAME || "").trim().toLowerCase();
    if (explicit)
        return explicit;
    if (process.env.BREVO_API_KEY)
        return "brevo";
    return "resend";
}
//# sourceMappingURL=provider.js.map