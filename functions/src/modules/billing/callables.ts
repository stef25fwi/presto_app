import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  APP_BASE_URL,
  ENFORCE_APP_CHECK,
  PROJECT_REGION,
  STRIPE_PRICE_ILIPRESTO_PLUS,
  STRIPE_PRICE_ILIPRO,
  STRIPE_SECRETS,
} from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { getStripeClient } from "./stripe_client";

type PayablePlan = "ilipresto_plus" | "ilipro";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizePayablePlan(value: unknown): PayablePlan {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "ilipresto_plus" || normalized === "iliprestoplus" || normalized === "ilipresto+") {
    return "ilipresto_plus";
  }
  if (normalized === "ilipro") {
    return "ilipro";
  }
  throw new HttpsError("invalid-argument", "plan must be ilipresto_plus or ilipro");
}

function resolvePriceIdForPlan(plan: PayablePlan): string {
  const priceId = plan === "ilipresto_plus" ? STRIPE_PRICE_ILIPRESTO_PLUS : STRIPE_PRICE_ILIPRO;
  if (!priceId) {
    throw new HttpsError(
      "failed-precondition",
      `Stripe price id is not configured for plan ${plan}`,
    );
  }
  return priceId;
}

function toBillingHttpsError(error: unknown, fallbackMessage: string): HttpsError {
  if (error instanceof HttpsError) return error;
  if (error instanceof Error) return new HttpsError("internal", error.message || fallbackMessage);
  return new HttpsError("internal", fallbackMessage);
}

async function ensureStripeCustomerId(uid: string): Promise<string> {
  const userRef = db.collection(COLLECTIONS.users).doc(uid);
  const userSnap = await userRef.get();
  const userData = (userSnap.data() ?? {}) as Record<string, unknown>;

  const existingCustomerId = String(userData.stripeCustomerId || "").trim();
  if (existingCustomerId) return existingCustomerId;

  const stripe = getStripeClient();
  const email = String(userData.email || "").trim() || undefined;
  const displayName = String(userData.display_name || userData.displayName || "").trim() || undefined;

  const customer = await stripe.customers.create({
    email,
    name: displayName,
    metadata: { userId: uid },
  });

  await userRef.set({ stripeCustomerId: customer.id }, { merge: true });
  return customer.id;
}

export const createCheckoutSession = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, secrets: STRIPE_SECRETS },
  async (request) => {
    const uid = requireAuthUid(request);
    const plan = normalizePayablePlan(request.data?.plan);
    const priceId = resolvePriceIdForPlan(plan);

    try {
      const stripeCustomerId = await ensureStripeCustomerId(uid);
      const stripe = getStripeClient();

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        customer: stripeCustomerId,
        client_reference_id: uid,
        line_items: [{ price: priceId, quantity: 1 }],
        allow_promotion_codes: true,
        success_url: `${APP_BASE_URL}/abonnement?checkout=success`,
        cancel_url: `${APP_BASE_URL}/abonnement?checkout=cancel`,
        subscription_data: {
          metadata: { userId: uid, plan },
        },
        metadata: { userId: uid, plan },
      });

      if (!session.url) {
        throw new HttpsError("internal", "Stripe did not return a checkout URL");
      }

      return { ok: true, url: session.url };
    } catch (error) {
      throw toBillingHttpsError(error, "Unable to create checkout session");
    }
  },
);

export const createBillingPortalSession = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK, secrets: STRIPE_SECRETS },
  async (request) => {
    const uid = requireAuthUid(request);

    try {
      const userSnap = await db.collection(COLLECTIONS.users).doc(uid).get();
      const stripeCustomerId = String(userSnap.data()?.stripeCustomerId || "").trim();
      if (!stripeCustomerId) {
        throw new HttpsError(
          "failed-precondition",
          "No Stripe customer is linked to this account yet",
        );
      }

      const stripe = getStripeClient();
      const session = await stripe.billingPortal.sessions.create({
        customer: stripeCustomerId,
        return_url: `${APP_BASE_URL}/abonnement`,
      });

      return { ok: true, url: session.url };
    } catch (error) {
      throw toBillingHttpsError(error, "Unable to create billing portal session");
    }
  },
);

export { normalizePayablePlan, resolvePriceIdForPlan };
