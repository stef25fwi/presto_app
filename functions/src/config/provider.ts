import { EMAIL_PROVIDER_NAME } from "./env";

export function getProviderName(): string {
  const explicit = String(EMAIL_PROVIDER_NAME || "").trim().toLowerCase();
  if (explicit) return explicit;
  if (process.env.BREVO_API_KEY) return "brevo";
  return "resend";
}
