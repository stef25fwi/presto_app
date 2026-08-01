"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSubscriptionPortalSession = exports.getSubscriptionCheckoutStatus = exports.auditStripeCatalog = exports.createSubscriptionCheckoutSession = void 0;
exports.normalizePlan = normalizePlan;
exports.checkoutSuccessUrl = checkoutSuccessUrl;
exports.idempotencyKey = idempotencyKey;
exports.checkoutIdempotencyBucket = checkoutIdempotencyBucket;
exports.isBlockingSubscriptionStatus = isBlockingSubscriptionStatus;
exports.isCheckoutIntentFresh = isCheckoutIntentFresh;
const crypto_1 = require("crypto");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const DEFAULT_STRIPE_RETURN_BASE_URL = "https://ilipresto.web.app";
const CHECKOUT_IDEMPOTENCY_WINDOW_MS = 10 * 60 * 1000;
const CHECKOUT_EXPIRATION_SECONDS = 30 * 60;
const PRICE_CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const CHECKOUT_SESSION_CACHE_SAFETY_MS = 60 * 1000;
const BLOCKING_SUBSCRIPTION_STATUSES = new Set([
    "active",
    "trialing",
    "past_due",
    "unpaid",
    "incomplete",
    "paused",
]);
const EXPECTED_PRICE_BY_PLAN = {
    ilipresto_plus: { amount: 199, currency: "eur", interval: "month" },
    ilipro: { amount: 999, currency: "eur", interval: "month" },
};
const validatedPriceCache = new Map();
class StripeApiError extends Error {
    status;
    code;
    type;
    param;
    constructor(message, status, code, type, param) {
        super(message);
        this.status = status;
        this.code = code;
        this.type = type;
        this.param = param;
        this.name = "StripeApiError";
    }
}
function asMap(value) {
    return value && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
}
function asString(value) {
    return String(value ?? "").trim();
}
function asNumber(value) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
}
function normalizePlan(value) {
    const raw = asString(value).toLowerCase();
    if (raw === "ilipresto_plus" || raw === "iliprestoplus" || raw === "ilipresto+") {
        return "ilipresto_plus";
    }
    if (raw === "ilipro") {
        return "ilipro";
    }
    throw new https_1.HttpsError("invalid-argument", "plan abonnement invalide");
}
function priceIdForPlan(plan) {
    const canonicalSecret = plan === "ilipresto_plus"
        ? env_1.STRIPE_PRICE_ILIPRESTO_PLUS.value()
        : env_1.STRIPE_PRICE_ILIPRO.value();
    const candidates = plan === "ilipresto_plus"
        ? [
            canonicalSecret,
            process.env.STRIPE_PRICE_ILIPRESTO_PLUS,
            process.env.STRIPE_PRICE_ILIPRESTO_PLUS_MONTHLY,
            process.env.STRIPE_PRICE_ILIPRESTO,
        ]
        : [
            canonicalSecret,
            process.env.STRIPE_PRICE_ILIPRO,
            process.env.STRIPE_PRICE_ILIPRO_MONTHLY,
        ];
    const priceId = candidates
        .map(asString)
        .find((value) => value.length > 0);
    if (!priceId) {
        const secretName = plan === "ilipresto_plus"
            ? "STRIPE_PRICE_ILIPRESTO_PLUS"
            : "STRIPE_PRICE_ILIPRO";
        throw new https_1.HttpsError("failed-precondition", `Price ID Stripe manquant pour ${plan}. Configure le secret Firebase ${secretName}.`);
    }
    if (!priceId.startsWith("price_")) {
        throw new https_1.HttpsError("failed-precondition", `Identifiant Stripe invalide pour ${plan} : une valeur commençant par price_ est attendue.`);
    }
    return priceId;
}
function stripeReturnBaseUrl() {
    const configured = asString(process.env.STRIPE_RETURN_BASE_URL);
    const value = configured || DEFAULT_STRIPE_RETURN_BASE_URL;
    const uri = new URL(value);
    if (uri.protocol !== "https:") {
        throw new https_1.HttpsError("failed-precondition", "STRIPE_RETURN_BASE_URL doit utiliser HTTPS");
    }
    return value.replace(/\/+$/, "");
}
function subscriptionReturnUrl(status, includeCheckoutSession = false) {
    const url = new URL("/account", `${stripeReturnBaseUrl()}/`);
    url.searchParams.set("section", "subscriptions");
    if (status)
        url.searchParams.set("subscription", status);
    if (includeCheckoutSession) {
        url.searchParams.set("session_id", "{CHECKOUT_SESSION_ID}");
    }
    return url.toString().replace("%7BCHECKOUT_SESSION_ID%7D", "{CHECKOUT_SESSION_ID}");
}
function checkoutSuccessUrl() {
    const configured = asString(process.env.STRIPE_SUCCESS_URL);
    if (!configured)
        return subscriptionReturnUrl("success", true);
    const url = new URL(configured);
    if (!url.searchParams.has("session_id")) {
        url.searchParams.set("session_id", "{CHECKOUT_SESSION_ID}");
    }
    return url.toString().replace("%7BCHECKOUT_SESSION_ID%7D", "{CHECKOUT_SESSION_ID}");
}
function cancelUrl() {
    return asString(process.env.STRIPE_CANCEL_URL) || subscriptionReturnUrl("cancel");
}
function portalReturnUrl() {
    return asString(process.env.STRIPE_PORTAL_RETURN_URL) || subscriptionReturnUrl("portal");
}
function stripeSecret() {
    const secret = env_1.STRIPE_SECRET_KEY.value().trim();
    if (!secret) {
        throw new https_1.HttpsError("failed-precondition", "STRIPE_SECRET_KEY non configurée");
    }
    if (!secret.startsWith("sk_test_") && !secret.startsWith("sk_live_")) {
        throw new https_1.HttpsError("failed-precondition", "STRIPE_SECRET_KEY invalide");
    }
    return secret;
}
function stripeMode() {
    return stripeSecret().startsWith("sk_live_") ? "live" : "test";
}
/**
 * Clé d'idempotence Stripe dérivée d'éléments stables de la requête.
 *
 * Stripe déduplique sur cette clé pendant 24 h : deux appels identiques (double
 * clic, rejeu réseau, nouvelle tentative du client) ne créent qu'un objet. Le
 * condensat garantit une longueur bornée et ne fuit aucun identifiant en clair.
 */
function idempotencyKey(parts) {
    const digest = (0, crypto_1.createHash)("sha256")
        .update(parts.map((part) => String(part)).join(":"))
        .digest("hex");
    return `ilipresto_${digest.slice(0, 48)}`;
}
function checkoutIdempotencyBucket(nowMs) {
    return Math.floor(nowMs / CHECKOUT_IDEMPOTENCY_WINDOW_MS);
}
function isBlockingSubscriptionStatus(status) {
    const raw = asString(status).toLowerCase().replace(/[\s-]/g, "_");
    const normalized = raw === "pastdue" ? "past_due" : raw;
    return BLOCKING_SUBSCRIPTION_STATUSES.has(normalized);
}
function isCheckoutIntentFresh(expiresAtMs, nowMs) {
    return Number.isFinite(expiresAtMs)
        && expiresAtMs > nowMs + CHECKOUT_SESSION_CACHE_SAFETY_MS;
}
async function stripeRequest(method, path, params, options) {
    const headers = {
        Authorization: `Bearer ${stripeSecret()}`,
        "Content-Type": "application/x-www-form-urlencoded",
    };
    if (options?.idempotencyKey) {
        headers["Idempotency-Key"] = options.idempotencyKey;
    }
    const init = { method, headers };
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
        const error = asMap(data.error);
        throw new StripeApiError(asString(error.message) || `Stripe API error ${response.status}`, response.status, asString(error.code), asString(error.type), asString(error.param));
    }
    return data;
}
function mapStripeError(error) {
    if (error instanceof https_1.HttpsError)
        return error;
    if (error instanceof StripeApiError) {
        console.error("STRIPE_API_ERROR", {
            status: error.status,
            code: error.code,
            type: error.type,
            param: error.param,
            message: error.message,
        });
        if (error.status === 429) {
            return new https_1.HttpsError("resource-exhausted", "Stripe est momentanément saturé. Réessayez dans un instant.");
        }
        if (error.status >= 500) {
            return new https_1.HttpsError("unavailable", "Stripe est temporairement indisponible.");
        }
        return new https_1.HttpsError("failed-precondition", error.message);
    }
    console.error("STRIPE_UNEXPECTED_ERROR", error);
    return new https_1.HttpsError("internal", "Une erreur inattendue empêche l’ouverture de Stripe.");
}
function extractEmail(userData, authEmail) {
    return asString(userData.email || userData.emailAddress || authEmail);
}
function extractName(userData, authName) {
    return asString(userData.displayName || userData.display_name || userData.name || authName);
}
async function retrieveCustomer(customerId) {
    try {
        const customer = await stripeRequest("GET", `/v1/customers/${encodeURIComponent(customerId)}`);
        return customer.deleted === true ? null : customer;
    }
    catch (error) {
        if (error instanceof StripeApiError && (error.status === 404 || error.code === "resource_missing")) {
            return null;
        }
        throw error;
    }
}
async function syncStripeCustomer(customerId, userId, email, name) {
    const params = {
        "metadata[firebaseUid]": userId,
        "preferred_locales[0]": "fr",
    };
    if (email)
        params.email = email;
    if (name)
        params.name = name;
    await stripeRequest("POST", `/v1/customers/${encodeURIComponent(customerId)}`, params, {
        idempotencyKey: idempotencyKey([
            "customer-sync",
            userId,
            customerId,
            email,
            name,
        ]),
    });
}
async function getOrCreateStripeCustomer(userId, authToken) {
    const userRef = firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId);
    const userSnap = await userRef.get();
    const userData = (userSnap.data() || {});
    const email = extractEmail(userData, asString(authToken.email));
    const name = extractName(userData, asString(authToken.name));
    const existing = asString(userData.stripeCustomerId || userData.stripe_customer_id);
    if (existing) {
        const customer = await retrieveCustomer(existing);
        if (customer) {
            await syncStripeCustomer(existing, userId, email, name);
            return existing;
        }
        await userRef.set({
            stripeCustomerId: firestore_1.FieldValue.delete(),
            stripe_customer_id: firestore_1.FieldValue.delete(),
            stripeUpdatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    const day = new Date().toISOString().slice(0, 10);
    const params = {
        "metadata[firebaseUid]": userId,
        "preferred_locales[0]": "fr",
    };
    if (email)
        params.email = email;
    if (name)
        params.name = name;
    const customer = await stripeRequest("POST", "/v1/customers", params, { idempotencyKey: idempotencyKey(["customer-create", userId, day]) });
    const customerId = asString(customer.id);
    if (!customerId) {
        throw new https_1.HttpsError("internal", "Stripe n’a pas retourné de customer id");
    }
    const winnerCustomerId = await firestore_2.db.runTransaction(async (transaction) => {
        const latest = await transaction.get(userRef);
        const latestData = (latest.data() || {});
        const alreadyStored = asString(latestData.stripeCustomerId || latestData.stripe_customer_id);
        if (alreadyStored)
            return alreadyStored;
        transaction.set(userRef, {
            stripeCustomerId: customerId,
            stripe_customer_id: customerId,
            stripeMode: stripeMode(),
            stripeUpdatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return customerId;
    });
    return winnerCustomerId;
}
function subscriptionPriceId(subscription) {
    const items = asMap(subscription.items);
    const rows = Array.isArray(items.data) ? items.data : [];
    const first = asMap(rows[0]);
    return asString(asMap(first.price).id);
}
async function validatePriceForPlan(plan, priceId) {
    const cacheUntil = validatedPriceCache.get(priceId) || 0;
    if (cacheUntil > Date.now())
        return;
    let price;
    try {
        price = await stripeRequest("GET", `/v1/prices/${encodeURIComponent(priceId)}`);
    }
    catch (error) {
        if (error instanceof StripeApiError && (error.status === 404 || error.code === "resource_missing")) {
            throw new https_1.HttpsError("failed-precondition", `Le Price ID ${priceId} n’existe pas dans le même environnement Stripe que STRIPE_SECRET_KEY.`);
        }
        throw error;
    }
    const expectation = EXPECTED_PRICE_BY_PLAN[plan];
    const recurring = asMap(price.recurring);
    const problems = [];
    if (price.active !== true)
        problems.push("prix inactif");
    if (asString(price.type) !== "recurring")
        problems.push("prix non récurrent");
    if (asString(price.currency).toLowerCase() !== expectation.currency) {
        problems.push(`devise attendue ${expectation.currency.toUpperCase()}`);
    }
    if (asNumber(price.unit_amount) !== expectation.amount) {
        problems.push(`montant attendu ${(expectation.amount / 100).toFixed(2)} €`);
    }
    if (asString(recurring.interval) !== expectation.interval) {
        problems.push(`périodicité attendue ${expectation.interval}`);
    }
    const productId = asString(price.product);
    if (productId.startsWith("prod_")) {
        const product = await stripeRequest("GET", `/v1/products/${encodeURIComponent(productId)}`);
        if (product.active === false)
            problems.push("produit inactif");
    }
    if (problems.length > 0) {
        throw new https_1.HttpsError("failed-precondition", `Configuration Stripe incorrecte pour ${plan} : ${problems.join(", ")}.`);
    }
    validatedPriceCache.set(priceId, Date.now() + PRICE_CACHE_TTL_MS);
}
async function findBlockingSubscription(customerId) {
    const subscriptions = await stripeRequest("GET", "/v1/subscriptions", {
        customer: customerId,
        status: "all",
        limit: "100",
    });
    const rows = Array.isArray(subscriptions.data) ? subscriptions.data : [];
    return rows.find((subscription) => isBlockingSubscriptionStatus(subscription.status)) || null;
}
async function createPortalUrl(customerId) {
    const params = {
        customer: customerId,
        return_url: portalReturnUrl(),
        locale: "fr",
    };
    const configuration = asString(process.env.STRIPE_PORTAL_CONFIGURATION_ID);
    if (configuration)
        params.configuration = configuration;
    return stripeRequest("POST", "/v1/billing_portal/sessions", params);
}
async function existingSubscriptionDestination(subscription, customerId) {
    const status = asString(subscription.status).toLowerCase();
    const subscriptionId = asString(subscription.id);
    const latestInvoiceId = asString(subscription.latest_invoice);
    if (["incomplete", "past_due", "unpaid"].includes(status) && latestInvoiceId) {
        const invoice = await stripeRequest("GET", `/v1/invoices/${encodeURIComponent(latestInvoiceId)}`);
        const hostedInvoiceUrl = asString(invoice.hosted_invoice_url);
        if (hostedInvoiceUrl) {
            return { url: hostedInvoiceUrl, destination: "invoice", subscriptionId };
        }
    }
    const portal = await createPortalUrl(customerId);
    const portalUrl = asString(portal.url);
    if (!portalUrl) {
        throw new https_1.HttpsError("internal", "Stripe n’a pas retourné d’URL de gestion");
    }
    return { url: portalUrl, destination: "portal", subscriptionId };
}
function checkoutSource(value) {
    return asString(value).replace(/[^a-zA-Z0-9_.:-]/g, "_").slice(0, 80) || "unknown";
}
async function logCheckoutSession(session, data) {
    const sessionId = asString(session.id);
    if (!sessionId)
        return;
    await firestore_2.db.collection("stripe_checkout_sessions").doc(sessionId).set({
        ...data,
        stripe_mode: stripeMode(),
        stripe_session_status: asString(session.status || "open"),
        created_at: firestore_1.FieldValue.serverTimestamp(),
        updated_at: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
}
function checkoutIntentDocumentId(userId, plan) {
    return `${userId}_${plan}`;
}
function localCustomerId(userData) {
    return asString(userData.stripeCustomerId || userData.stripe_customer_id);
}
function localSubscriptionId(userData) {
    return asString(userData.stripeSubscriptionId || userData.stripe_subscription_id);
}
function localSubscriptionStatus(userData) {
    return asString(userData.subscriptionStatus || userData.subscription_status);
}
function isMissingCustomerError(error) {
    return error instanceof StripeApiError
        && (error.status === 404 || error.code === "resource_missing")
        && (!error.param || error.param === "customer");
}
async function clearInvalidCustomerReference(userRef) {
    await userRef.set({
        stripeCustomerId: firestore_1.FieldValue.delete(),
        stripe_customer_id: firestore_1.FieldValue.delete(),
        stripeUpdatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function destinationForLocalSubscription(userData) {
    const status = localSubscriptionStatus(userData);
    if (!isBlockingSubscriptionStatus(status))
        return null;
    let customerId = localCustomerId(userData);
    const subscriptionId = localSubscriptionId(userData);
    const normalizedStatus = status.toLowerCase().replace(/[\s-]/g, "_");
    if (["incomplete", "past_due", "pastdue", "unpaid"].includes(normalizedStatus) && subscriptionId) {
        const subscription = await stripeRequest("GET", `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
        customerId = customerId || asString(subscription.customer);
        if (!customerId) {
            throw new https_1.HttpsError("failed-precondition", "Votre abonnement Stripe est en cours de synchronisation. Réessayez dans un instant.");
        }
        return existingSubscriptionDestination(subscription, customerId);
    }
    if (!customerId && subscriptionId) {
        const subscription = await stripeRequest("GET", `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
        customerId = asString(subscription.customer);
    }
    if (!customerId) {
        throw new https_1.HttpsError("failed-precondition", "Votre abonnement Stripe est en cours de synchronisation. Réessayez dans un instant.");
    }
    const portal = await createPortalUrl(customerId);
    const portalUrl = asString(portal.url);
    if (!portalUrl) {
        throw new https_1.HttpsError("internal", "Stripe n’a pas retourné d’URL de gestion");
    }
    return { url: portalUrl, destination: "portal", subscriptionId };
}
exports.createSubscriptionCheckoutSession = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: env_1.STRIPE_CHECKOUT_SECRETS,
    timeoutSeconds: 30,
    minInstances: 1,
    maxInstances: 20,
    concurrency: 80,
    memory: "256MiB",
}, async (request) => {
    const startedAt = Date.now();
    try {
        const auth = request.auth;
        if (!auth?.uid) {
            throw new https_1.HttpsError("unauthenticated", "Connexion requise pour s’abonner");
        }
        const plan = normalizePlan(request.data?.plan ?? request.data?.subscriptionPlan);
        const priceId = priceIdForPlan(plan);
        const source = checkoutSource(request.data?.source);
        const userRef = firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(auth.uid);
        const intentRef = firestore_2.db
            .collection("stripe_checkout_intents")
            .doc(checkoutIntentDocumentId(auth.uid, plan));
        const [userSnap, intentSnap] = await Promise.all([
            userRef.get(),
            intentRef.get(),
        ]);
        const userData = (userSnap.data() || {});
        const existingDestination = await destinationForLocalSubscription(userData);
        if (existingDestination) {
            console.info("STRIPE_CHECKOUT_PERFORMANCE", {
                userId: auth.uid,
                plan,
                destination: existingDestination.destination,
                durationMs: Date.now() - startedAt,
                source,
            });
            return {
                ok: true,
                ...existingDestination,
                reason: "existing_subscription",
                serverDurationMs: Date.now() - startedAt,
            };
        }
        const intentData = (intentSnap.data() || {});
        const cachedUrl = asString(intentData.url);
        const cachedExpiresAtMs = asNumber(intentData.expires_at_ms);
        if (cachedUrl && isCheckoutIntentFresh(cachedExpiresAtMs, Date.now())) {
            console.info("STRIPE_CHECKOUT_PERFORMANCE", {
                userId: auth.uid,
                plan,
                destination: "checkout",
                cacheHit: true,
                durationMs: Date.now() - startedAt,
                source,
            });
            return {
                ok: true,
                url: cachedUrl,
                destination: "checkout",
                sessionId: asString(intentData.session_id),
                expiresAt: cachedExpiresAtMs,
                cacheHit: true,
                serverDurationMs: Date.now() - startedAt,
            };
        }
        const nowSeconds = Math.floor(Date.now() / 1000);
        const email = extractEmail(userData, asString(auth.token?.email));
        const customerId = localCustomerId(userData);
        const params = {
            mode: "subscription",
            client_reference_id: auth.uid,
            success_url: checkoutSuccessUrl(),
            cancel_url: cancelUrl(),
            locale: "fr",
            billing_address_collection: "auto",
            allow_promotion_codes: process.env.STRIPE_ALLOW_PROMOTION_CODES === "false" ? "false" : "true",
            "line_items[0][price]": priceId,
            "line_items[0][quantity]": "1",
            "metadata[firebaseUid]": auth.uid,
            "metadata[plan]": plan,
            "metadata[source]": source,
            "subscription_data[metadata][firebaseUid]": auth.uid,
            "subscription_data[metadata][plan]": plan,
            "subscription_data[metadata][source]": source,
            expires_at: String(nowSeconds + CHECKOUT_EXPIRATION_SECONDS),
        };
        if (customerId) {
            params.customer = customerId;
            params["customer_update[address]"] = "auto";
            params["customer_update[name]"] = "auto";
        }
        else if (email) {
            params.customer_email = email;
        }
        if (plan === "ilipro") {
            params["tax_id_collection[enabled]"] = "true";
        }
        if (process.env.STRIPE_AUTOMATIC_TAX_ENABLED === "true") {
            params["automatic_tax[enabled]"] = "true";
        }
        const bucket = checkoutIdempotencyBucket(Date.now());
        const checkoutKeyParts = [
            "checkout",
            stripeMode(),
            auth.uid,
            plan,
            bucket,
        ];
        let session;
        try {
            session = await stripeRequest("POST", "/v1/checkout/sessions", params, { idempotencyKey: idempotencyKey(checkoutKeyParts) });
        }
        catch (error) {
            if (!customerId || !isMissingCustomerError(error))
                throw error;
            await clearInvalidCustomerReference(userRef);
            delete params.customer;
            delete params["customer_update[address]"];
            delete params["customer_update[name]"];
            if (email)
                params.customer_email = email;
            session = await stripeRequest("POST", "/v1/checkout/sessions", params, {
                idempotencyKey: idempotencyKey([
                    ...checkoutKeyParts,
                    "customer-recovery",
                ]),
            });
        }
        const url = asString(session.url);
        const sessionId = asString(session.id);
        if (!url || !sessionId) {
            throw new https_1.HttpsError("internal", "Stripe n’a pas retourné de session de paiement valide");
        }
        const expiresAtMs = asNumber(session.expires_at) > 0
            ? asNumber(session.expires_at) * 1000
            : Date.now() + CHECKOUT_EXPIRATION_SECONDS * 1000;
        const batch = firestore_2.db.batch();
        batch.set(intentRef, {
            user_id: auth.uid,
            plan,
            price_id: priceId,
            session_id: sessionId,
            url,
            expires_at_ms: expiresAtMs,
            stripe_mode: stripeMode(),
            source,
            updated_at: firestore_1.FieldValue.serverTimestamp(),
            created_at: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        batch.set(firestore_2.db.collection("stripe_checkout_sessions").doc(sessionId), {
            user_id: auth.uid,
            customer_id: customerId || null,
            plan,
            price_id: priceId,
            source,
            destination: "checkout",
            stripe_mode: stripeMode(),
            stripe_session_status: asString(session.status || "open"),
            expires_at: expiresAtMs,
            created_at: firestore_1.FieldValue.serverTimestamp(),
            updated_at: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        await batch.commit();
        console.info("STRIPE_CHECKOUT_PERFORMANCE", {
            userId: auth.uid,
            plan,
            destination: "checkout",
            cacheHit: false,
            customerReused: Boolean(customerId),
            durationMs: Date.now() - startedAt,
            source,
        });
        return {
            ok: true,
            url,
            destination: "checkout",
            sessionId,
            expiresAt: expiresAtMs,
            cacheHit: false,
            serverDurationMs: Date.now() - startedAt,
        };
    }
    catch (error) {
        throw mapStripeError(error);
    }
});
exports.auditStripeCatalog = (0, scheduler_1.onSchedule)({
    region: env_1.PROJECT_REGION,
    schedule: "every 6 hours",
    timeZone: "UTC",
    secrets: env_1.STRIPE_CHECKOUT_SECRETS,
    timeoutSeconds: 60,
    memory: "256MiB",
}, async () => {
    const startedAt = Date.now();
    try {
        validatedPriceCache.clear();
        const plusPriceId = priceIdForPlan("ilipresto_plus");
        const proPriceId = priceIdForPlan("ilipro");
        await Promise.all([
            validatePriceForPlan("ilipresto_plus", plusPriceId),
            validatePriceForPlan("ilipro", proPriceId),
        ]);
        await firestore_2.db.collection("stripe_runtime_health").doc("catalog").set({
            ok: true,
            stripe_mode: stripeMode(),
            ilipresto_plus_price_id: plusPriceId,
            ilipro_price_id: proPriceId,
            checked_at: firestore_1.FieldValue.serverTimestamp(),
            duration_ms: Date.now() - startedAt,
            error: firestore_1.FieldValue.delete(),
        }, { merge: true });
    }
    catch (error) {
        await firestore_2.db.collection("stripe_runtime_health").doc("catalog").set({
            ok: false,
            stripe_mode: stripeMode(),
            checked_at: firestore_1.FieldValue.serverTimestamp(),
            duration_ms: Date.now() - startedAt,
            error: error instanceof Error ? error.message : String(error),
        }, { merge: true });
        throw error;
    }
});
exports.getSubscriptionCheckoutStatus = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.STRIPE_SECRET_KEY],
    timeoutSeconds: 30,
}, async (request) => {
    try {
        const auth = request.auth;
        if (!auth?.uid) {
            throw new https_1.HttpsError("unauthenticated", "Connexion requise");
        }
        const sessionId = asString(request.data?.sessionId || request.data?.session_id);
        if (!sessionId.startsWith("cs_")) {
            throw new https_1.HttpsError("invalid-argument", "Session Stripe invalide");
        }
        const session = await stripeRequest("GET", `/v1/checkout/sessions/${encodeURIComponent(sessionId)}`, { "expand[0]": "subscription" });
        const metadata = asMap(session.metadata);
        const ownerUid = asString(session.client_reference_id || metadata.firebaseUid);
        if (ownerUid !== auth.uid) {
            throw new https_1.HttpsError("permission-denied", "Cette session Stripe ne vous appartient pas");
        }
        const subscription = asMap(session.subscription);
        const status = asString(session.status);
        const paymentStatus = asString(session.payment_status);
        const subscriptionStatus = asString(subscription.status);
        await firestore_2.db.collection("stripe_checkout_sessions").doc(sessionId).set({
            stripe_session_status: status,
            payment_status: paymentStatus,
            subscription_status: subscriptionStatus,
            subscription_id: asString(subscription.id || session.subscription),
            updated_at: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return {
            ok: true,
            sessionId,
            status,
            paymentStatus,
            subscriptionStatus,
            complete: status === "complete",
            paid: paymentStatus === "paid" || subscriptionStatus === "active" || subscriptionStatus === "trialing",
            plan: asString(metadata.plan),
        };
    }
    catch (error) {
        throw mapStripeError(error);
    }
});
exports.createSubscriptionPortalSession = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.STRIPE_SECRET_KEY],
    timeoutSeconds: 30,
}, async (request) => {
    try {
        const auth = request.auth;
        if (!auth?.uid) {
            throw new https_1.HttpsError("unauthenticated", "Connexion requise pour gérer l’abonnement");
        }
        const customerId = await getOrCreateStripeCustomer(auth.uid, auth.token);
        const session = await createPortalUrl(customerId);
        const url = asString(session.url);
        if (!url) {
            throw new https_1.HttpsError("internal", "Stripe n’a pas retourné d’URL de gestion");
        }
        await firestore_2.db.collection("stripe_portal_sessions").add({
            user_id: auth.uid,
            customer_id: customerId,
            source: checkoutSource(request.data?.source),
            stripe_mode: stripeMode(),
            created_at: firestore_1.FieldValue.serverTimestamp(),
        });
        return {
            ok: true,
            url,
            destination: "portal",
        };
    }
    catch (error) {
        throw mapStripeError(error);
    }
});
//# sourceMappingURL=callables.js.map