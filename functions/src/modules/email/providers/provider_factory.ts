import {
  BREVO_API_KEY,
  BREVO_WEBHOOK_SECRET,
  EMAIL_PROVIDER_API_KEY,
  EMAIL_PROVIDER_WEBHOOK_SECRET,
} from "../../../config/env";
import { getProviderName } from "../../../config/provider";
import { EmailProvider } from "./email_provider.interface";
import { BrevoProvider } from "./brevo_provider";
import { ResendProvider } from "./resend_provider";

function hasValue(value: string): boolean {
  return String(value || "").trim().length > 0;
}

/**
 * Les secrets arrivent de Secret Manager via `process.env`, qui conserve les
 * espaces et sauts de ligne de la valeur stockée. Un secret créé avec un `\n`
 * final — cas courant d'un `echo` sans `-n` ou d'un collage en console — ferait
 * échouer toute comparaison stricte avec la même valeur lue ailleurs, et
 * produirait un en-tête HTTP invalide côté envoi. Normaliser ici, au seul point
 * d'entrée des secrets dans le runtime.
 */
function readSecret(value: string): string {
  return String(value || "").trim();
}

export function createEmailProvider(): EmailProvider {
  const providerName = String(getProviderName() || "resend").toLowerCase();
  const brevoApiKey = readSecret(BREVO_API_KEY.value());
  const brevoWebhookSecret = readSecret(BREVO_WEBHOOK_SECRET.value());
  const resendApiKey = readSecret(EMAIL_PROVIDER_API_KEY.value());
  const resendWebhookSecret = readSecret(EMAIL_PROVIDER_WEBHOOK_SECRET.value());

  const hasBrevoConfig = hasValue(brevoApiKey) && hasValue(brevoWebhookSecret);
  const hasResendConfig = hasValue(resendApiKey) && hasValue(resendWebhookSecret);

  switch (providerName) {
    case "brevo": {
      if (!hasBrevoConfig) {
        throw new Error("Brevo provider selected but BREVO_API_KEY/BREVO_WEBHOOK_SECRET are not fully configured");
      }
      return new BrevoProvider(brevoApiKey, brevoWebhookSecret);
    }
    case "resend": {
      if (!hasResendConfig) {
        throw new Error("Resend provider selected but EMAIL_PROVIDER_API_KEY/EMAIL_PROVIDER_WEBHOOK_SECRET are not fully configured");
      }
      return new ResendProvider(resendApiKey, resendWebhookSecret);
    }
    default:
      throw new Error(`Unsupported EMAIL_PROVIDER_NAME: ${providerName}`);
  }
}
