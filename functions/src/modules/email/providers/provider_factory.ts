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

export function createEmailProvider(): EmailProvider {
  const providerName = String(getProviderName() || "resend").toLowerCase();

  switch (providerName) {
    case "brevo": {
      const apiKey = BREVO_API_KEY.value() || EMAIL_PROVIDER_API_KEY.value();
      const webhookSecret = BREVO_WEBHOOK_SECRET.value() || EMAIL_PROVIDER_WEBHOOK_SECRET.value();
      return new BrevoProvider(apiKey, webhookSecret);
    }
    case "resend": {
      const apiKey = EMAIL_PROVIDER_API_KEY.value() || BREVO_API_KEY.value();
      const webhookSecret = EMAIL_PROVIDER_WEBHOOK_SECRET.value() || BREVO_WEBHOOK_SECRET.value();
      return new ResendProvider(apiKey, webhookSecret);
    }
    default:
      throw new Error(`Unsupported EMAIL_PROVIDER_NAME: ${providerName}`);
  }
}
