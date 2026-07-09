"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createBillingPortalSession = exports.createCheckoutSession = void 0;
exports.normalizePayablePlan = normalizePayablePlan;
exports.resolvePriceIdForPlan = resolvePriceIdForPlan;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const stripe_client_1 = require("./stripe_client");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function normalizePayablePlan(value) {
    const normalized = String(value ?? "").trim().toLowerCase();
    if (normalized === "ilipresto_plus" || normalized === "iliprestoplus" || normalized === "ilipresto+") {
        return "ilipresto_plus";
    }
    if (normalized === "ilipro") {
        return "ilipro";
    }
    throw new https_1.HttpsError("invalid-argument", "plan must be ilipresto_plus or ilipro");
}
function resolvePriceIdForPlan(plan) {
    const priceId = plan === "ilipresto_plus" ? env_1.STRIPE_PRICE_ILIPRESTO_PLUS : env_1.STRIPE_PRICE_ILIPRO;
    if (!priceId) {
        throw new https_1.HttpsError("failed-precondition", `Stripe price id is not configured for plan ${plan}`);
    }
    return priceId;
}
function toBillingHttpsError(error, fallbackMessage) {
    if (error instanceof https_1.HttpsError)
        return error;
    if (error instanceof Error)
        return new https_1.HttpsError("internal", error.message || fallbackMessage);
    return new https_1.HttpsError("internal", fallbackMessage);
}
async function ensureStripeCustomerId(uid) {
    const userRef = firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(uid);
    const userSnap = await userRef.get();
    const userData = (userSnap.data() ?? {});
    const existingCustomerId = String(userData.stripeCustomerId || "").trim();
    if (existingCustomerId)
        return existingCustomerId;
    const stripe = (0, stripe_client_1.getStripeClient)();
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
exports.createCheckoutSession = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, secrets: env_1.STRIPE_SECRETS }, async (request) => {
    const uid = requireAuthUid(request);
    const plan = normalizePayablePlan(request.data?.plan);
    const priceId = resolvePriceIdForPlan(plan);
    try {
        const stripeCustomerId = await ensureStripeCustomerId(uid);
        const stripe = (0, stripe_client_1.getStripeClient)();
        const session = await stripe.checkout.sessions.create({
            mode: "subscription",
            customer: stripeCustomerId,
            client_reference_id: uid,
            line_items: [{ price: priceId, quantity: 1 }],
            allow_promotion_codes: true,
            success_url: `${env_1.APP_BASE_URL}/abonnement?checkout=success`,
            cancel_url: `${env_1.APP_BASE_URL}/abonnement?checkout=cancel`,
            subscription_data: {
                metadata: { userId: uid, plan },
            },
            metadata: { userId: uid, plan },
        });
        if (!session.url) {
            throw new https_1.HttpsError("internal", "Stripe did not return a checkout URL");
        }
        return { ok: true, url: session.url };
    }
    catch (error) {
        throw toBillingHttpsError(error, "Unable to create checkout session");
    }
});
exports.createBillingPortalSession = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK, secrets: env_1.STRIPE_SECRETS }, async (request) => {
    const uid = requireAuthUid(request);
    try {
        const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(uid).get();
        const stripeCustomerId = String(userSnap.data()?.stripeCustomerId || "").trim();
        if (!stripeCustomerId) {
            throw new https_1.HttpsError("failed-precondition", "No Stripe customer is linked to this account yet");
        }
        const stripe = (0, stripe_client_1.getStripeClient)();
        const session = await stripe.billingPortal.sessions.create({
            customer: stripeCustomerId,
            return_url: `${env_1.APP_BASE_URL}/abonnement`,
        });
        return { ok: true, url: session.url };
    }
    catch (error) {
        throw toBillingHttpsError(error, "Unable to create billing portal session");
    }
});
//# sourceMappingURL=callables.js.map