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

export function createEmailProvider(): EmailProvider {
  const explicitProvider = String(process.env.EMAIL_PROVIDER_NAME || "").trim().toLowerCase();
  const providerName = String(getProviderName() || "resend").toLowerCase();
  const brevoApiKey = BREVO_API_KEY.value();
  const brevoWebhookSecret = BREVO_WEBHOOK_SECRET.value();
  const resendApiKey = EMAIL_PROVIDER_API_KEY.value();
  const resendWebhookSecret = EMAIL_PROVIDER_WEBHOOK_SECRET.value();

  const hasBrevoConfig = hasValue(brevoApiKey) && hasValue(brevoWebhookSecret);
  const hasResendConfig = hasValue(resendApiKey) && hasValue(resendWebhookSecret);

  if (!explicitProvider && hasBrevoConfig && hasResendConfig) {
    throw new Error("EMAIL_PROVIDER_NAME is required when both Brevo and generic provider secrets are configured");
  }

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
