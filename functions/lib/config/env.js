"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EMAIL_PROVIDER_SECRETS = exports.ENFORCE_APP_CHECK = exports.IS_PROD = exports.IS_EMULATOR = exports.MARKETPLACE_VIEW_RATE_LIMIT = exports.MARKETPLACE_RECAPTCHA_MIN_SCORE = exports.MARKETPLACE_REPORT_REVIEW_THRESHOLD = exports.MARKETPLACE_AUTO_APPROVE_ENABLED = exports.MARKETPLACE_LISTING_DRAFT_LIMIT = exports.MARKETPLACE_MAX_MEDIA_COUNT = exports.RECAPTCHA_ENTERPRISE_SITE_KEY = exports.GCP_PROJECT_ID = exports.APP_BASE_URL = exports.PROJECT_REGION = exports.EMAIL_FROM = exports.DEFAULT_TIMEZONE = exports.DEFAULT_LOCALE = exports.EMAIL_PROVIDER_NAME = exports.STRIPE_CHECKOUT_SECRETS = exports.STRIPE_PRICE_ILIPRO = exports.STRIPE_PRICE_ILIPRESTO_PLUS = exports.STRIPE_WEBHOOK_SECRET = exports.STRIPE_SECRET_KEY = exports.BREVO_WEBHOOK_SECRET = exports.BREVO_API_KEY = exports.EMAIL_PROVIDER_WEBHOOK_SECRET = exports.EMAIL_PROVIDER_API_KEY = exports.OPENAI_API_KEY = void 0;
exports.assertProdSecurityConfig = assertProdSecurityConfig;
const params_1 = require("firebase-functions/params");
const app_check_policy_1 = require("./app_check_policy");
exports.OPENAI_API_KEY = (0, params_1.defineSecret)("OPENAI_API_KEY");
// VEO_API_KEY intentionally NOT defined here: defineSecret() registers the
// secret in firebase-functions' global params registry the moment this
// module loads, which happens on every deploy (env.ts is imported by
// index.ts). Since VEO_API_KEY doesn't exist yet in Secret Manager, that
// registration makes `firebase deploy` prompt interactively to create it,
// which hangs non-interactive CI — regardless of whether adminGenerateVideo
// (the only consumer, currently excluded from the build) is reachable.
// Defined locally in videomaker.ts instead, so it's only registered once
// that module is actually re-enabled and required.
exports.EMAIL_PROVIDER_API_KEY = (0, params_1.defineSecret)("EMAIL_PROVIDER_API_KEY");
exports.EMAIL_PROVIDER_WEBHOOK_SECRET = (0, params_1.defineSecret)("EMAIL_PROVIDER_WEBHOOK_SECRET");
exports.BREVO_API_KEY = (0, params_1.defineSecret)("BREVO_API_KEY");
exports.BREVO_WEBHOOK_SECRET = (0, params_1.defineSecret)("BREVO_WEBHOOK_SECRET");
exports.STRIPE_SECRET_KEY = (0, params_1.defineSecret)("STRIPE_SECRET_KEY");
exports.STRIPE_WEBHOOK_SECRET = (0, params_1.defineSecret)("STRIPE_WEBHOOK_SECRET");
exports.STRIPE_PRICE_ILIPRESTO_PLUS = (0, params_1.defineSecret)("STRIPE_PRICE_ILIPRESTO_PLUS");
exports.STRIPE_PRICE_ILIPRO = (0, params_1.defineSecret)("STRIPE_PRICE_ILIPRO");
exports.STRIPE_CHECKOUT_SECRETS = [
    exports.STRIPE_SECRET_KEY,
    exports.STRIPE_PRICE_ILIPRESTO_PLUS,
    exports.STRIPE_PRICE_ILIPRO,
];
exports.EMAIL_PROVIDER_NAME = process.env.EMAIL_PROVIDER_NAME || "";
exports.DEFAULT_LOCALE = (process.env.DEFAULT_LOCALE || "fr");
exports.DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Europe/Paris";
exports.EMAIL_FROM = process.env.EMAIL_FROM || "iliprestō <noreply@ilipresto.fr>";
exports.PROJECT_REGION = process.env.FUNCTION_REGION || "europe-west1";
exports.APP_BASE_URL = process.env.APP_BASE_URL || "https://ilipresto.fr";
exports.GCP_PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
exports.RECAPTCHA_ENTERPRISE_SITE_KEY = process.env.RECAPTCHA_ENTERPRISE_SITE_KEY || "";
exports.MARKETPLACE_MAX_MEDIA_COUNT = Number(process.env.MARKETPLACE_MAX_MEDIA_COUNT || 10);
exports.MARKETPLACE_LISTING_DRAFT_LIMIT = Number(process.env.MARKETPLACE_LISTING_DRAFT_LIMIT || 50);
exports.MARKETPLACE_AUTO_APPROVE_ENABLED = process.env.MARKETPLACE_AUTO_APPROVE_ENABLED !== "false";
exports.MARKETPLACE_REPORT_REVIEW_THRESHOLD = Number(process.env.MARKETPLACE_REPORT_REVIEW_THRESHOLD || 3);
exports.MARKETPLACE_RECAPTCHA_MIN_SCORE = Number(process.env.MARKETPLACE_RECAPTCHA_MIN_SCORE || 0.5);
exports.MARKETPLACE_VIEW_RATE_LIMIT = Number(process.env.MARKETPLACE_VIEW_RATE_LIMIT || 20);
exports.IS_EMULATOR = process.env.FUNCTIONS_EMULATOR === "true" ||
    Boolean(process.env.FIREBASE_EMULATOR_HUB);
exports.IS_PROD = exports.GCP_PROJECT_ID === "presto-app-74abe";
const rawSafeMode = String(process.env.APPCHECK_SAFE_MODE || "").toLowerCase() === "true";
const rawEnforce = String(process.env.ENFORCE_APP_CHECK || "").toLowerCase();
exports.ENFORCE_APP_CHECK = (0, app_check_policy_1.resolveAppCheckEnforcement)({
    isEmulator: exports.IS_EMULATOR,
    isProduction: exports.IS_PROD,
    enforceValue: rawEnforce,
    safeModeValue: rawSafeMode,
});
function assertProdSecurityConfig() {
    if (exports.IS_PROD && !exports.IS_EMULATOR && !exports.ENFORCE_APP_CHECK) {
        console.error("CRITICAL_APP_CHECK_DISABLED", {
            projectId: exports.GCP_PROJECT_ID,
            rawEnforce,
            rawSafeMode,
            emulator: exports.IS_EMULATOR,
        });
    }
}
assertProdSecurityConfig();
exports.EMAIL_PROVIDER_SECRETS = [
    exports.EMAIL_PROVIDER_API_KEY,
    exports.EMAIL_PROVIDER_WEBHOOK_SECRET,
    exports.BREVO_API_KEY,
    exports.BREVO_WEBHOOK_SECRET,
];
//# sourceMappingURL=env.js.map