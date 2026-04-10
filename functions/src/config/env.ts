import { defineSecret } from "firebase-functions/params";

export const EMAIL_PROVIDER_API_KEY = defineSecret("EMAIL_PROVIDER_API_KEY");
export const EMAIL_PROVIDER_WEBHOOK_SECRET = defineSecret("EMAIL_PROVIDER_WEBHOOK_SECRET");
export const BREVO_API_KEY = defineSecret("BREVO_API_KEY");
export const BREVO_WEBHOOK_SECRET = defineSecret("BREVO_WEBHOOK_SECRET");

export const EMAIL_PROVIDER_NAME = process.env.EMAIL_PROVIDER_NAME || "";
export const DEFAULT_LOCALE = (process.env.DEFAULT_LOCALE || "fr") as "fr" | "en";
export const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Europe/Paris";
export const EMAIL_FROM = process.env.EMAIL_FROM || "PRESTO <sahai.stephane@gmail.com>";

export const PROJECT_REGION = process.env.FUNCTION_REGION || "europe-west1";
const appCheckRequested = String(process.env.ENFORCE_APP_CHECK || "").toLowerCase() === "true";
// Safe mode is enabled by default to avoid locking out users when client App Check
// setup is incomplete (missing token/provider mismatch/domain mismatch).
// To enforce App Check again in production, set APPCHECK_SAFE_MODE=false.
const appCheckSafeMode = String(process.env.APPCHECK_SAFE_MODE || "true").toLowerCase() !== "false";
export const ENFORCE_APP_CHECK = appCheckRequested && !appCheckSafeMode;
export const APP_BASE_URL = process.env.APP_BASE_URL || "https://presto.app";
export const GCP_PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
export const RECAPTCHA_ENTERPRISE_SITE_KEY = process.env.RECAPTCHA_ENTERPRISE_SITE_KEY || "";
export const MARKETPLACE_MAX_MEDIA_COUNT = Number(process.env.MARKETPLACE_MAX_MEDIA_COUNT || 10);
export const MARKETPLACE_LISTING_DRAFT_LIMIT = Number(process.env.MARKETPLACE_LISTING_DRAFT_LIMIT || 50);
export const MARKETPLACE_AUTO_APPROVE_ENABLED = process.env.MARKETPLACE_AUTO_APPROVE_ENABLED !== "false";
export const MARKETPLACE_REPORT_REVIEW_THRESHOLD = Number(process.env.MARKETPLACE_REPORT_REVIEW_THRESHOLD || 3);
export const MARKETPLACE_RECAPTCHA_MIN_SCORE = Number(process.env.MARKETPLACE_RECAPTCHA_MIN_SCORE || 0.5);
export const MARKETPLACE_VIEW_RATE_LIMIT = Number(process.env.MARKETPLACE_VIEW_RATE_LIMIT || 20);

export const EMAIL_PROVIDER_SECRETS = [
	EMAIL_PROVIDER_API_KEY,
	EMAIL_PROVIDER_WEBHOOK_SECRET,
	BREVO_API_KEY,
	BREVO_WEBHOOK_SECRET,
];
