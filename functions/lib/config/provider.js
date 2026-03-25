"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProviderName = getProviderName;
function getProviderName() {
    const explicit = String(process.env.EMAIL_PROVIDER_NAME || "").trim().toLowerCase();
    if (explicit)
        return explicit;
    if (process.env.BREVO_API_KEY)
        return "brevo";
    return "resend";
}
//# sourceMappingURL=provider.js.map