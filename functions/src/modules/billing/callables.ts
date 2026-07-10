import { HttpsError, onCall } from "firebase-functions/v2/https";
import { APP_BASE_URL, ENFORCE_APP_CHECK, PROJECT_REGION, STRIPE_SECRET_KEY } from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

type StripeObject = Record<string, unknown>;

type StripeCustomer = StripeObject & {
  id?: string;
};

type StripeSession = StripeObject & {
  id?: string;
  url?: string | null;
};

function normalizePlan(value: unknown): "ilipresto_plus" | "ilipro" {
  const raw = String(value || "").trim().toLowerCase();
  if (raw === "ilipresto_plus" || raw === "iliprestoplus" || raw === "ilipresto+") {
    return "ilipresto_plus";
  }
  if (raw === "ilipro") {
    return "ilipro";
  }
  throw new HttpsError("invalid-argument", "plan abonnement invalide");
}

function priceIdForPlan(plan: "ilipresto_plus" | "ilipro"): string {
  const candidates = plan === "ilipresto_plus"
    ? [
        process.env.STRIPE_PRICE_ILIPRESTO_PLUS,
        process.env.STRIPE_PRICE_ILIPRESTO_PLUS_MONTHLY,
        process.env.STRIPE_PRICE_ILIPRESTO,
      ]
    : [
        process.env.STRIPE_PRICE_ILIPRO,
        process.env.STRIPE_PRICE_ILIPRO_MONTHLY,
      ];

  const priceId = candidates.map((value) => String(value || "").trim()).find((value) => value.length > 0);
  if (!priceId) {
    throw new HttpsError(
      "failed-precondition",
      `price id Stripe manquant pour ${plan}. Configure STRIPE_PRICE_ILIPRESTO_PLUS ou STRIPE_PRICE_ILIPRO.`,
    );
  }
  return priceId;
}

function successUrl(): string {
  return String(process.env.STRIPE_SUCCESS_URL || `${APP_BASE_URL}/account?subscription=success`).trim();
}

function cancelUrl(): string {
  return String(process.env.STRIPE_CANCEL_URL || `${APP_BASE_URL}/account?subscription=cancel`).trim();
}

function portalReturnUrl(): string {
  return String(process.env.STRIPE_PORTAL_RETURN_URL || `${APP_BASE_URL}/account`).trim();
}

function stripeSecret(): string {
  const secret = STRIPE_SECRET_KEY.value().trim();
  if (!secret) {
    throw new HttpsError("failed-precondition", "STRIPE_SECRET_KEY non configurée");
  }
  return secret;
}

async function stripeRequest<T extends StripeObject>(
  method: "GET" | "POST",
  path: string,
  params?: Record<string, string>,
): Promise<T> {
  const init: RequestInit = {
    method,
    headers: {
      Authorization: `Bearer ${stripeSecret()}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
  };

  let url = `https://api.stripe.com${path}`;
  if (params && Object.keys(params).length > 0) {
    const encoded = new URLSearchParams(params);
    if (method === "GET") {
      url = `${url}?${encoded.toString()}`;
    } else {
      init.body = encoded.toString();
    }
  }

  const response = await fetch(url, init);
  const data = await response.json().catch(() => ({})) as StripeObject;
  if (!response.ok) {
    const error = data.error as StripeObject | undefined;
    const message = String(error?.message || `Stripe API error ${response.status}`);
    throw new HttpsError("internal", message);
  }
  return data as T;
}

function extractEmail(userData: StripeObject, authEmail: string | undefined): string {
  return String(userData.email || userData.emailAddress || authEmail || "").trim();
}

function extractName(userData: StripeObject, authName: string | undefined): string {
  return String(userData.displayName || userData.display_name || userData.name || authName || "").trim();
}

async function getOrCreateStripeCustomer(userId: string, authToken: StripeObject): Promise<string> {
  const userRef = db.collection(COLLECTIONS.users).doc(userId);
  const userSnap = await userRef.get();
  const userData = (userSnap.data() || {}) as StripeObject;

  const existing = String(userData.stripeCustomerId || userData.stripe_customer_id || "").trim();
  if (existing) return existing;

  const email = extractEmail(userData, String(authToken.email || ""));
  const name = extractName(userData, String(authToken.name || ""));

  const customer = await stripeRequest<StripeCustomer>("POST", "/v1/customers", {
    ...(email ? { email } : {}),
    ...(name ? { name } : {}),
    "metadata[firebaseUid]": userId,
  });

  const customerId = String(customer.id || "").trim();
  if (!customerId) {
    throw new HttpsError("internal", "Stripe n’a pas retourné de customer id");
  }

  await userRef.set({
    stripeCustomerId: customerId,
    stripe_customer_id: customerId,
    stripeUpdatedAt: Date.now(),
  }, { merge: true });

  return customerId;
}

export const createSubscriptionCheckoutSession = onCall({
  region: PROJECT_REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
  secrets: [STRIPE_SECRET_KEY],
}, async (request) => {
  const auth = request.auth;
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Connexion requise pour s’abonner");
  }

  const plan = normalizePlan(request.data?.plan);
  const priceId = priceIdForPlan(plan);
  const customerId = await getOrCreateStripeCustomer(auth.uid, auth.token as StripeObject);

  const session = await stripeRequest<StripeSession>("POST", "/v1/checkout/sessions", {
    mode: "subscription",
    customer: customerId,
    client_reference_id: auth.uid,
    success_url: successUrl(),
    cancel_url: cancelUrl(),
    "line_items[0][price]": priceId,
    "line_items[0][quantity]": "1",
    "metadata[firebaseUid]": auth.uid,
    "metadata[plan]": plan,
    "subscription_data[metadata][firebaseUid]": auth.uid,
    "subscription_data[metadata][plan]": plan,
  });

  const url = String(session.url || "").trim();
  if (!url) {
    throw new HttpsError("internal", "Stripe n’a pas retourné d’URL de paiement");
  }

  return {
    ok: true,
    url,
    sessionId: String(session.id || ""),
  };
});

export const createSubscriptionPortalSession = onCall({
  region: PROJECT_REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
  secrets: [STRIPE_SECRET_KEY],
}, async (request) => {
  const auth = request.auth;
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Connexion requise pour gérer l’abonnement");
  }

  const customerId = await getOrCreateStripeCustomer(auth.uid, auth.token as StripeObject);
  const session = await stripeRequest<StripeSession>("POST", "/v1/billing_portal/sessions", {
    customer: customerId,
    return_url: portalReturnUrl(),
  });

  const url = String(session.url || "").trim();
  if (!url) {
    throw new HttpsError("internal", "Stripe n’a pas retourné d’URL de gestion");
  }

  return {
    ok: true,
    url,
  };
});
