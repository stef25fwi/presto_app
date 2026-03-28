"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EMAIL_PROVIDER_SECRETS = exports.MARKETPLACE_VIEW_RATE_LIMIT = exports.MARKETPLACE_RECAPTCHA_MIN_SCORE = exports.MARKETPLACE_REPORT_REVIEW_THRESHOLD = exports.MARKETPLACE_AUTO_APPROVE_ENABLED = exports.MARKETPLACE_LISTING_DRAFT_LIMIT = exports.MARKETPLACE_MAX_MEDIA_COUNT = exports.RECAPTCHA_ENTERPRISE_SITE_KEY = exports.GCP_PROJECT_ID = exports.APP_BASE_URL = exports.PROJECT_REGION = exports.EMAIL_FROM = exports.DEFAULT_TIMEZONE = exports.DEFAULT_LOCALE = exports.EMAIL_PROVIDER_NAME = exports.BREVO_WEBHOOK_SECRET = exports.BREVO_API_KEY = exports.EMAIL_PROVIDER_WEBHOOK_SECRET = exports.EMAIL_PROVIDER_API_KEY = void 0;
const params_1 = require("firebase-functions/params");
exports.EMAIL_PROVIDER_API_KEY = (0, params_1.defineSecret)("EMAIL_PROVIDER_API_KEY");
exports.EMAIL_PROVIDER_WEBHOOK_SECRET = (0, params_1.defineSecret)("EMAIL_PROVIDER_WEBHOOK_SECRET");
exports.BREVO_API_KEY = (0, params_1.defineSecret)("BREVO_API_KEY");
exports.BREVO_WEBHOOK_SECRET = (0, params_1.defineSecret)("BREVO_WEBHOOK_SECRET");
exports.EMAIL_PROVIDER_NAME = process.env.EMAIL_PROVIDER_NAME || "";
exports.DEFAULT_LOCALE = (process.env.DEFAULT_LOCALE || "fr");
exports.DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Europe/Paris";
exports.EMAIL_FROM = process.env.EMAIL_FROM || "PRESTO <no-reply@presto.app>";
exports.PROJECT_REGION = process.env.FUNCTION_REGION || "europe-west1";
exports.APP_BASE_URL = process.env.APP_BASE_URL || "https://presto.app";
exports.GCP_PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
exports.RECAPTCHA_ENTERPRISE_SITE_KEY = process.env.RECAPTCHA_ENTERPRISE_SITE_KEY || "";
exports.MARKETPLACE_MAX_MEDIA_COUNT = Number(process.env.MARKETPLACE_MAX_MEDIA_COUNT || 10);
exports.MARKETPLACE_LISTING_DRAFT_LIMIT = Number(process.env.MARKETPLACE_LISTING_DRAFT_LIMIT || 50);
exports.MARKETPLACE_AUTO_APPROVE_ENABLED = process.env.MARKETPLACE_AUTO_APPROVE_ENABLED !== "false";
exports.MARKETPLACE_REPORT_REVIEW_THRESHOLD = Number(process.env.MARKETPLACE_REPORT_REVIEW_THRESHOLD || 3);
exports.MARKETPLACE_RECAPTCHA_MIN_SCORE = Number(process.env.MARKETPLACE_RECAPTCHA_MIN_SCORE || 0.5);
exports.MARKETPLACE_VIEW_RATE_LIMIT = Number(process.env.MARKETPLACE_VIEW_RATE_LIMIT || 20);
exports.EMAIL_PROVIDER_SECRETS = [
    exports.EMAIL_PROVIDER_API_KEY,
    exports.EMAIL_PROVIDER_WEBHOOK_SECRET,
    exports.BREVO_API_KEY,
    exports.BREVO_WEBHOOK_SECRET,
];
//# sourceMappingURL=env.js.map