import { onCall } from "firebase-functions/v2/https";
import {
  ENFORCE_APP_CHECK,
  PROJECT_REGION,
  STRIPE_CHECKOUT_SECRETS,
} from "../../config/env";
import { createSubscriptionCheckoutSession as checkoutHandler } from "./callables";
import { assertCommercialBillingEnabled } from "./operating_mode_guard";

export const guardedCreateSubscriptionCheckoutSession = onCall({
  region: PROJECT_REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
  secrets: STRIPE_CHECKOUT_SECRETS,
  timeoutSeconds: 30,
  minInstances: 1,
  maxInstances: 20,
  concurrency: 80,
  memory: "256MiB",
}, async (request) => {
  await assertCommercialBillingEnabled();
  return checkoutHandler.run(request);
});
