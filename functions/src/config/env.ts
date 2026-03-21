import { defineSecret } from "firebase-functions/params";

export const EMAIL_PROVIDER_API_KEY = defineSecret("EMAIL_PROVIDER_API_KEY");
export const EMAIL_PROVIDER_WEBHOOK_SECRET = defineSecret("EMAIL_PROVIDER_WEBHOOK_SECRET");

export const EMAIL_PROVIDER_NAME = process.env.EMAIL_PROVIDER_NAME || "resend";
export const DEFAULT_LOCALE = (process.env.DEFAULT_LOCALE || "fr") as "fr" | "en";
export const DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Europe/Paris";
export const EMAIL_FROM = process.env.EMAIL_FROM || "PRESTO <no-reply@presto.app>";

export const PROJECT_REGION = process.env.FUNCTION_REGION || "europe-west1";
