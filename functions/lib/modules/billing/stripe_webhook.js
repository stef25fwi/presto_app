"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleStripeWebhook = void 0;
const crypto_1 = require("crypto");
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const WEBHOOK_EVENTS_COLLECTION = "stripe_webhook_events";
const SIGNATURE_TOLERANCE_SECONDS = 5 * 60;
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
function unixMs(value) {
    const seconds = asNumber(value);
    return seconds > 0 ? seconds * 1000 : null;
}
function webhookSecret() {
    const value = env_1.STRIPE_WEBHOOK_SECRET.value().trim();
    if (!value)
        throw new Error("STRIPE_WEBHOOK_SECRET non configuré");
    return value;
}
function stripeSecret() {
    const value = env_1.STRIPE_SECRET_KEY.value().trim();
    if (!value)
        throw new Error("STRIPE_SECRET_KEY non configurée");
    return value;
}
function parseStripeSignature(header) {
    const parts = header.split(",").map((part) => part.trim());
    const timestamp = parts.find((part) => part.startsWith("t="))?.slice(2) ?? "";
    const signatures = parts
        .filter((part) => part.startsWith("v1="))
        .map((part) => part.slice(3))
        .filter(Boolean);
    return { timestamp, signatures };
}
function safeHexEqual(left, right) {
    try {
        const leftBuffer = Buffer.from(left, "hex");
        const rightBuffer = Buffer.from(right, "hex");
        return leftBuffer.length === rightBuffer.length && (0, crypto_1.timingSafeEqual)(leftBuffer, rightBuffer);
    }
    catch {
        return false;
    }
}
function verifyStripeSignature(rawBody, signatureHeader) {
    const { timestamp, signatures } = parseStripeSignature(signatureHeader);
    if (!timestamp || signatures.length === 0)
        throw new Error("Signature Stripe absente ou invalide");
    const timestampSeconds = Number(timestamp);
    if (!Number.isFinite(timestampSeconds))
        throw new Error("Horodatage Stripe invalide");
    const age = Math.abs(Math.floor(Date.now() / 1000) - timestampSeconds);
    if (age > SIGNATURE_TOLERANCE_SECONDS)
        throw new Error("Signature Stripe expirée");
    const signedPayload = `${timestamp}.${rawBody.toString("utf8")}`;
    const expected = (0, crypto_1.createHmac)("sha256", webhookSecret()).update(signedPayload).digest("hex");
    if (!signatures.some((signature) => safeHexEqual(signature, expected))) {
        throw new Error("Signature Stripe incorrecte");
    }
}
async function stripeGet(path) {
    const response = await fetch(`https://api.stripe.com${path}`, {
        headers: { Authorization: `Bearer ${stripeSecret()}` },
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        const error = asMap(data.error);
        throw new Error(asString(error.message) || `Stripe API error ${response.status}`);
    }
    return data;
}
function priceIdFromSubscription(subscription) {
    const items = asMap(subscription.items);
    const rows = Array.isArray(items.data) ? items.data : [];
    const first = asMap(rows[0]);
    return asString(asMap(first.price).id);
}
function planFromStripe(subscription) {
    const metadata = asMap(subscription.metadata);
    const metadataPlan = asString(metadata.plan).toLowerCase();
    if (["ilipro"].includes(metadataPlan))
        return "ilipro";
    if (["ilipresto_plus", "iliprestoplus", "ilipresto+"].includes(metadataPlan))
        return "ilipresto_plus";
    const priceId = priceIdFromSubscription(subscription);
    const iliproPrices = [process.env.STRIPE_PRICE_ILIPRO, process.env.STRIPE_PRICE_ILIPRO_MONTHLY]
        .map(asString)
        .filter(Boolean);
    const plusPrices = [
        process.env.STRIPE_PRICE_ILIPRESTO_PLUS,
        process.env.STRIPE_PRICE_ILIPRESTO_PLUS_MONTHLY,
        process.env.STRIPE_PRICE_ILIPRESTO,
    ].map(asString).filter(Boolean);
    if (iliproPrices.includes(priceId))
        return "ilipro";
    if (plusPrices.includes(priceId))
        return "ilipresto_plus";
    return "free";
}
function appPlan(plan) {
    return plan === "ilipresto_plus" ? "iliprestoPlus" : plan;
}
function appStatus(rawStatus) {
    switch (rawStatus.toLowerCase()) {
        case "active":
        case "trialing":
            return "active";
        case "past_due":
        case "unpaid":
        case "incomplete":
        case "paused":
            return "pastDue";
        case "canceled":
        case "cancelled":
            return "canceled";
        default:
            return "inactive";
    }
}
async function findUserId(object) {
    const metadata = asMap(object.metadata);
    const direct = asString(metadata.firebaseUid || object.client_reference_id);
    if (direct)
        return direct;
    const customerId = asString(object.customer);
    if (!customerId)
        return "";
    for (const field of ["stripeCustomerId", "stripe_customer_id"]) {
        const snap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).where(field, "==", customerId).limit(1).get();
        if (!snap.empty)
            return snap.docs[0].id;
    }
    return "";
}
async function syncSubscription(subscription, eventId) {
    const subscriptionId = asString(subscription.id);
    if (!subscriptionId)
        throw new Error("Abonnement Stripe sans identifiant");
    const userId = await findUserId(subscription);
    if (!userId)
        throw new Error(`Utilisateur Firebase introuvable pour ${subscriptionId}`);
    const rawStatus = asString(subscription.status);
    const normalizedStatus = appStatus(rawStatus);
    const plan = planFromStripe(subscription);
    const customerId = asString(subscription.customer);
    const priceId = priceIdFromSubscription(subscription);
    const currentPeriodEnd = unixMs(subscription.current_period_end);
    const cancelAt = unixMs(subscription.cancel_at);
    const canceledAt = unixMs(subscription.canceled_at);
    const cancelAtPeriodEnd = subscription.cancel_at_period_end === true;
    const subscriptionData = {
        stripe_subscription_id: subscriptionId,
        stripe_customer_id: customerId,
        stripe_price_id: priceId,
        user_id: userId,
        plan,
        plan_name: plan === "ilipro" ? "ilipro" : plan === "ilipresto_plus" ? "iliprestō+" : "Gratuit",
        status: rawStatus,
        subscription_status: normalizedStatus,
        current_period_start: unixMs(subscription.current_period_start),
        current_period_end: currentPeriodEnd,
        renewal_at: cancelAtPeriodEnd ? null : currentPeriodEnd,
        cancel_at_period_end: cancelAtPeriodEnd,
        cancel_at: cancelAt,
        canceled_at: canceledAt,
        currency: asString(subscription.currency || "eur").toUpperCase(),
        latest_invoice_id: asString(subscription.latest_invoice),
        last_stripe_event_id: eventId,
        stripe_updated_at: firestore_1.FieldValue.serverTimestamp(),
    };
    const userData = {
        stripeCustomerId: customerId,
        stripe_customer_id: customerId,
        stripeSubscriptionId: subscriptionId,
        stripe_subscription_id: subscriptionId,
        stripePriceId: priceId,
        stripe_price_id: priceId,
        subscriptionPlan: normalizedStatus === "active" ? appPlan(plan) : "free",
        subscriptionStatus: normalizedStatus,
        subscriptionExpiresAt: currentPeriodEnd ? new Date(currentPeriodEnd) : null,
        subscriptionCancelAtPeriodEnd: cancelAtPeriodEnd,
        stripeUpdatedAt: firestore_1.FieldValue.serverTimestamp(),
        lastStripeEventId: eventId,
    };
    const batch = firestore_2.db.batch();
    batch.set(firestore_2.db.collection(constants_1.COLLECTIONS.subscriptions).doc(subscriptionId), subscriptionData, { merge: true });
    batch.set(firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId), userData, { merge: true });
    await batch.commit();
}
async function syncInvoice(invoice, eventId) {
    const invoiceId = asString(invoice.id);
    if (!invoiceId)
        throw new Error("Facture Stripe sans identifiant");
    const userId = await findUserId(invoice);
    const subscriptionId = asString(invoice.subscription);
    const status = asString(invoice.status || (invoice.paid === true ? "paid" : "open"));
    const data = {
        stripe_invoice_id: invoiceId,
        stripe_subscription_id: subscriptionId,
        stripe_customer_id: asString(invoice.customer),
        user_id: userId,
        status,
        amount_due: asNumber(invoice.amount_due),
        amount_paid: asNumber(invoice.amount_paid),
        amount_remaining: asNumber(invoice.amount_remaining),
        currency: asString(invoice.currency || "eur").toUpperCase(),
        attempt_count: asNumber(invoice.attempt_count),
        next_retry_at: unixMs(invoice.next_payment_attempt),
        hosted_invoice_url: asString(invoice.hosted_invoice_url),
        invoice_pdf: asString(invoice.invoice_pdf),
        period_start: unixMs(invoice.period_start),
        period_end: unixMs(invoice.period_end),
        last_stripe_event_id: eventId,
        stripe_updated_at: firestore_1.FieldValue.serverTimestamp(),
    };
    await firestore_2.db.collection(constants_1.COLLECTIONS.billingInvoices).doc(invoiceId).set(data, { merge: true });
    if (subscriptionId) {
        const subscription = await stripeGet(`/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
        await syncSubscription(subscription, eventId);
    }
}
async function processEvent(event) {
    const object = asMap(event.data?.object);
    switch (event.type) {
        case "checkout.session.completed": {
            const subscriptionId = asString(object.subscription);
            if (subscriptionId) {
                const subscription = await stripeGet(`/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
                await syncSubscription(subscription, event.id);
            }
            return;
        }
        case "customer.subscription.created":
        case "customer.subscription.updated":
        case "customer.subscription.deleted":
        case "customer.subscription.paused":
        case "customer.subscription.resumed":
            await syncSubscription(object, event.id);
            return;
        case "invoice.created":
        case "invoice.finalized":
        case "invoice.paid":
        case "invoice.payment_succeeded":
        case "invoice.payment_failed":
        case "invoice.voided":
            await syncInvoice(object, event.id);
            return;
        default:
            return;
    }
}
exports.handleStripeWebhook = (0, https_1.onRequest)({
    region: env_1.PROJECT_REGION,
    secrets: [env_1.STRIPE_SECRET_KEY, env_1.STRIPE_WEBHOOK_SECRET],
    timeoutSeconds: 60,
}, async (request, response) => {
    if (request.method !== "POST") {
        response.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const rawBody = request.rawBody;
        const signature = asString(request.headers["stripe-signature"]);
        verifyStripeSignature(rawBody, signature);
        const event = JSON.parse(rawBody.toString("utf8"));
        if (!event.id || !event.type)
            throw new Error("Événement Stripe invalide");
        const eventRef = firestore_2.db.collection(WEBHOOK_EVENTS_COLLECTION).doc(event.id);
        const shouldProcess = await firestore_2.db.runTransaction(async (transaction) => {
            const snap = await transaction.get(eventRef);
            if (snap.exists && snap.data()?.status === "processed")
                return false;
            transaction.set(eventRef, {
                event_id: event.id,
                event_type: event.type,
                stripe_created_at: event.created ? event.created * 1000 : null,
                status: "processing",
                attempts: firestore_1.FieldValue.increment(1),
                received_at: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            return true;
        });
        if (!shouldProcess) {
            response.status(200).json({ received: true, duplicate: true });
            return;
        }
        await processEvent(event);
        await eventRef.set({
            status: "processed",
            processed_at: firestore_1.FieldValue.serverTimestamp(),
            error: firestore_1.FieldValue.delete(),
        }, { merge: true });
        response.status(200).json({ received: true });
    }
    catch (error) {
        console.error("STRIPE_WEBHOOK_ERROR", error);
        response.status(400).send(error instanceof Error ? error.message : "Webhook Stripe invalide");
    }
});
//# sourceMappingURL=stripe_webhook.js.map