import { EMAIL_PROVIDER_API_KEY, EMAIL_PROVIDER_WEBHOOK_SECRET } from "../../../config/env";
import { getProviderName } from "../../../config/provider";
import { EmailProvider } from "./email_provider.interface";
import { ResendProvider } from "./resend_provider";

export function createEmailProvider(): EmailProvider {
  const providerName = getProviderName();
  const apiKey = EMAIL_PROVIDER_API_KEY.value();
  const webhookSecret = EMAIL_PROVIDER_WEBHOOK_SECRET.value();

  switch (providerName) {
    case "resend":
    default:
      return new ResendProvider(apiKey, webhookSecret);
  }
}
