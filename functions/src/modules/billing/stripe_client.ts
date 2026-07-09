import Stripe from "stripe";
import { STRIPE_SECRET_KEY } from "../../config/env";

let cachedClient: Stripe | null = null;

/**
 * Lazily builds the Stripe SDK client. Must only be called from inside a
 * function handler (never at module scope) since Secret Manager values are
 * only resolved once the function actually runs.
 */
export function getStripeClient(): Stripe {
  if (cachedClient) return cachedClient;

  const secretKey = STRIPE_SECRET_KEY.value();
  if (!secretKey) {
    throw new Error("STRIPE_SECRET_KEY is not configured");
  }

  cachedClient = new Stripe(secretKey, {
    apiVersion: "2026-06-24.dahlia",
  });
  return cachedClient;
}
