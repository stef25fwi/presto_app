"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSubscriptionPortalSession = exports.createSubscriptionCheckoutSession = void 0;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
function normalizePlan(value) {
    const raw = String(value || "").trim().toLowerCase();
    if (raw === "ilipresto_plus" || raw === "iliprestoplus" || raw === "ilipresto+") {
        return "ilipresto_plus";
    }
    if (raw === "ilipro") {
        return "ilipro";
    }
    throw new https_1.HttpsError("invalid-argument", "plan abonnement invalide");
}
function priceIdForPlan(plan) {
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
        throw new https_1.HttpsError("failed-precondition", `price id Stripe manquant pour ${plan}. Configure STRIPE_PRICE_ILIPRESTO_PLUS ou STRIPE_PRICE_ILIPRO.`);
    }
    return priceId;
}
function successUrl() {
    return String(process.env.STRIPE_SUCCESS_URL || `${env_1.APP_BASE_URL}/account?subscription=success`).trim();
}
function cancelUrl() {
    return String(process.env.STRIPE_CANCEL_URL || `${env_1.APP_BASE_URL}/account?subscription=cancel`).trim();
}
function portalReturnUrl() {
    return String(process.env.STRIPE_PORTAL_RETURN_URL || `${env_1.APP_BASE_URL}/account`).trim();
}
function stripeSecret() {
    const secret = env_1.STRIPE_SECRET_KEY.value().trim();
    if (!secret) {
        throw new https_1.HttpsError("failed-precondition", "STRIPE_SECRET_KEY non configurée");
    }
    return secret;
}
async function stripeRequest(method, path, params) {
    const init = {
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
        }
        else {
            init.body = encoded.toString();
        }
    }
    const response = await fetch(url, init);
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        const error = data.error;
        const message = String(error?.message || `Stripe API error ${response.status}`);
        throw new https_1.HttpsError("internal", message);
    }
    return data;
}
function extractEmail(userData, authEmail) {
    return String(userData.email || userData.emailAddress || authEmail || "").trim();
}
function extractName(userData, authName) {
    return String(userData.displayName || userData.display_name || userData.name || authName || "").trim();
}
async function getOrCreateStripeCustomer(userId, authToken) {
    const userRef = firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId);
    const userSnap = await userRef.get();
    const userData = (userSnap.data() || {});
    const existing = String(userData.stripeCustomerId || userData.stripe_customer_id || "").trim();
    if (existing)
        return existing;
    const email = extractEmail(userData, String(authToken.email || ""));
    const name = extractName(userData, String(authToken.name || ""));
    const customer = await stripeRequest("POST", "/v1/customers", {
        ...(email ? { email } : {}),
        ...(name ? { name } : {}),
        "metadata[firebaseUid]": userId,
    });
    const customerId = String(customer.id || "").trim();
    if (!customerId) {
        throw new https_1.HttpsError("internal", "Stripe n’a pas retourné de customer id");
    }
    await userRef.set({
        stripeCustomerId: customerId,
        stripe_customer_id: customerId,
        stripeUpdatedAt: Date.now(),
    }, { merge: true });
    return customerId;
}
exports.createSubscriptionCheckoutSession = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.STRIPE_SECRET_KEY],
}, async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Connexion requise pour s’abonner");
    }
    const plan = normalizePlan(request.data?.plan);
    const priceId = priceIdForPlan(plan);
    const customerId = await getOrCreateStripeCustomer(auth.uid, auth.token);
    const session = await stripeRequest("POST", "/v1/checkout/sessions", {
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
        throw new https_1.HttpsError("internal", "Stripe n’a pas retourné d’URL de paiement");
    }
    return {
        ok: true,
        url,
        sessionId: String(session.id || ""),
    };
});
exports.createSubscriptionPortalSession = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.STRIPE_SECRET_KEY],
}, async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "Connexion requise pour gérer l’abonnement");
    }
    const customerId = await getOrCreateStripeCustomer(auth.uid, auth.token);
    const session = await stripeRequest("POST", "/v1/billing_portal/sessions", {
        customer: customerId,
        return_url: portalReturnUrl(),
    });
    const url = String(session.url || "").trim();
    if (!url) {
        throw new https_1.HttpsError("internal", "Stripe n’a pas retourné d’URL de gestion");
    }
    return {
        ok: true,
        url,
    };
});
//# sourceMappingURL=callables.js.map