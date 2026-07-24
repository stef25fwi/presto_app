import { defineSecret } from "firebase-functions/params";

import { resolveAppCheckEnforcement } from "./app_check_policy";

export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
// VEO_API_KEY intentionally NOT defined here: defineSecret() registers the
// secret in firebase-functions' global params registry the moment this
// module loads, which happens on every deploy (env.ts is imported by
// index.ts). Since VEO_API_KEY doesn't exist yet in Secret Manager, that
// registration makes `firebase deploy` prompt interactively to create it,
// which hangs non-interactive CI — regardless of whether adminGenerateVideo
// (the only consumer, currently excluded from the build) is reachable.
// Defined locally in videomaker.ts instead, so it's only registered once
// that module is actually re-enabled and required.
export const EMAIL_PROVIDER_API_KEY = defineSecret("EMAIL_PROVIDER_API_KEY");
export const EMAIL_PROVIDER_WEBHOOK_SECRET = defineSecret("EMAIL_PROVIDER_WEBHOOK_SECRET");
export const BREVO_API_KEY = defineSecret("BREVO_API_KEY");
export const BREVO_WEBHOOK_SECRET = defineSecret("BREVO_WEBHOOK_SECRET");
export const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
export const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
export const STRIPE_PRICE_ILIPRESTO_PLUS = defineSecret("STRIPE_PRICE_ILIPRESTO_PLUS");
export const STRIPE_PRICE_ILIPRO = defineSecret("STRIPE_PRICE_ILIPRO");

export const STRIPE_CHECKOUT_SECRETS = [
	STRIPE_SECRET_KEY,
	STRIPE_PRICE_ILIPRESTO_PLUS,
	STRIPE_PRICE_ILIPRO,
];

export const EMAIL_PROVIDER_NAME = process.env.EMAIL_PROVIDER_NAME || "";
export const DEFAULT_LOCALE = (process.env.DEFAULT_LOCALE || "fr") as "fr" | "en";
export const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Europe/Paris";
export const EMAIL_FROM = process.env.EMAIL_FROM || "iliprestō <noreply@ilipresto.fr>";

export const PROJECT_REGION = process.env.FUNCTION_REGION || "europe-west1";
export const APP_BASE_URL = process.env.APP_BASE_URL || "https://ilipresto.fr";
export const GCP_PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
export const RECAPTCHA_ENTERPRISE_SITE_KEY = process.env.RECAPTCHA_ENTERPRISE_SITE_KEY || "";
export const MARKETPLACE_MAX_MEDIA_COUNT = Number(process.env.MARKETPLACE_MAX_MEDIA_COUNT || 10);
export const MARKETPLACE_LISTING_DRAFT_LIMIT = Number(process.env.MARKETPLACE_LISTING_DRAFT_LIMIT || 50);
export const MARKETPLACE_AUTO_APPROVE_ENABLED = process.env.MARKETPLACE_AUTO_APPROVE_ENABLED !== "false";
export const MARKETPLACE_REPORT_REVIEW_THRESHOLD = Number(process.env.MARKETPLACE_REPORT_REVIEW_THRESHOLD || 3);
export const MARKETPLACE_RECAPTCHA_MIN_SCORE = Number(process.env.MARKETPLACE_RECAPTCHA_MIN_SCORE || 0.5);
export const MARKETPLACE_VIEW_RATE_LIMIT = Number(process.env.MARKETPLACE_VIEW_RATE_LIMIT || 20);

export const IS_EMULATOR =
	process.env.FUNCTIONS_EMULATOR === "true" ||
	Boolean(process.env.FIREBASE_EMULATOR_HUB);

export const IS_PROD = GCP_PROJECT_ID === "presto-app-74abe";

const rawSafeMode = String(process.env.APPCHECK_SAFE_MODE || "").toLowerCase() === "true";
const rawEnforce = String(process.env.ENFORCE_APP_CHECK || "").toLowerCase();

export const ENFORCE_APP_CHECK = resolveAppCheckEnforcement({
	isEmulator: IS_EMULATOR,
	isProduction: IS_PROD,
	enforceValue: rawEnforce,
	safeModeValue: rawSafeMode,
});

export function assertProdSecurityConfig(): void {
	if (IS_PROD && !IS_EMULATOR && !ENFORCE_APP_CHECK) {
		console.error("CRITICAL_APP_CHECK_DISABLED", {
			projectId: GCP_PROJECT_ID,
			rawEnforce,
			rawSafeMode,
			emulator: IS_EMULATOR,
		});
	}
}

assertProdSecurityConfig();

export const EMAIL_PROVIDER_SECRETS = [
	EMAIL_PROVIDER_API_KEY,
	EMAIL_PROVIDER_WEBHOOK_SECRET,
	BREVO_API_KEY,
	BREVO_WEBHOOK_SECRET,
];
