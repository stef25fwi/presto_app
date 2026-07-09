"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeWebhook = void 0;
exports.resolvePlanForPriceId = resolvePlanForPriceId;
exports.resolveInternalStatus = resolveInternalStatus;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const logger_1 = require("../../core/logger");
const constants_1 = require("../../shared/constants");
const stripe_client_1 = require("./stripe_client");
function resolvePlanForPriceId(priceId) {
    if (!priceId)
        return "free";
    if (priceId === env_1.STRIPE_PRICE_ILIPRESTO_PLUS)
        return "ilipresto_plus";
    if (priceId === env_1.STRIPE_PRICE_ILIPRO)
        return "ilipro";
    return "free";
}
function resolveInternalStatus(stripeStatus) {
    switch (stripeStatus) {
        case "active":
        case "trialing":
            return "active";
        case "past_due":
        case "unpaid":
            return "past_due";
        case "canceled":
        case "incomplete_expired":
            return "canceled";
        default:
            return "inactive";
    }
}
async function resolveUserIdForCustomer(customerId, metadataUserId) {
    const fromMetadata = String(metadataUserId || "").trim();
    if (fromMetadata)
        return fromMetadata;
    const snap = await firestore_1.db
        .collection(constants_1.COLLECTIONS.users)
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();
    const doc = snap.docs[0];
    return doc ? doc.id : null;
}
async function syncSubscriptionToFirestore(subscription) {
    const customerId = typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer.id;
    const userId = await resolveUserIdForCustomer(customerId, subscription.metadata?.userId);
    if (!userId) {
        logger_1.logger.warn("stripe_webhook_unresolved_customer", { customerId, subscriptionId: subscription.id });
        return;
    }
    const priceId = subscription.items.data[0]?.price?.id;
    const plan = resolvePlanForPriceId(priceId);
    const internalStatus = resolveInternalStatus(subscription.status);
    const currentPeriodEndMs = subscription.items.data[0]?.current_period_end
        ? subscription.items.data[0].current_period_end * 1000
        : Date.now();
    const isActivePlan = internalStatus === "active";
    await firestore_1.db.collection(constants_1.COLLECTIONS.subscriptions).doc(subscription.id).set({
        user_id: userId,
        stripe_customer_id: customerId,
        stripe_subscription_id: subscription.id,
        plan_name: plan,
        status: internalStatus,
        stripe_status: subscription.status,
        currency: subscription.currency,
        renewal_at: currentPeriodEndMs,
        cancel_at_period_end: subscription.cancel_at_period_end,
        updated_at: Date.now(),
    }, { merge: true });
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).set({
        subscriptionPlan: isActivePlan ? plan : "free",
        subscriptionStatus: internalStatus,
        subscriptionExpiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(currentPeriodEndMs),
        stripeCustomerId: customerId,
    }, { merge: true });
}
async function markSubscriptionCanceled(subscription) {
    const customerId = typeof subscription.customer === "string"
        ? subscription.customer
        : subscription.customer.id;
    const userId = await resolveUserIdForCustomer(customerId, subscription.metadata?.userId);
    if (!userId)
        return;
    await firestore_1.db.collection(constants_1.COLLECTIONS.subscriptions).doc(subscription.id).set({
        user_id: userId,
        status: "canceled",
        stripe_status: subscription.status,
        updated_at: Date.now(),
    }, { merge: true });
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).set({
        subscriptionPlan: "free",
        subscriptionStatus: "canceled",
    }, { merge: true });
}
async function syncInvoiceToFirestore(invoice, status) {
    const customerId = typeof invoice.customer === "string"
        ? invoice.customer
        : invoice.customer?.id;
    if (!customerId)
        return;
    const userId = await resolveUserIdForCustomer(customerId, undefined);
    if (!userId) {
        logger_1.logger.warn("stripe_webhook_invoice_unresolved_customer", { customerId, invoiceId: invoice.id });
        return;
    }
    await firestore_1.db.collection(constants_1.COLLECTIONS.billingInvoices).doc(invoice.id).set({
        user_id: userId,
        stripe_customer_id: customerId,
        status,
        amount_due: invoice.amount_due,
        amount_paid: invoice.amount_paid,
        currency: invoice.currency,
        updated_at: Date.now(),
    }, { merge: true });
}
exports.stripeWebhook = (0, https_1.onRequest)({ region: env_1.PROJECT_REGION, secrets: env_1.STRIPE_SECRETS }, async (req, res) => {
    const signature = req.headers["stripe-signature"];
    if (!signature || typeof signature !== "string") {
        res.status(400).send("Missing Stripe-Signature header");
        return;
    }
    const stripe = (0, stripe_client_1.getStripeClient)();
    let event;
    try {
        event = stripe.webhooks.constructEvent(req.rawBody, signature, env_1.STRIPE_WEBHOOK_SECRET.value());
    }
    catch (error) {
        logger_1.logger.warn("stripe_webhook_invalid_signature", {
            error: error instanceof Error ? error.message : String(error),
        });
        res.status(400).send("Invalid signature");
        return;
    }
    try {
        switch (event.type) {
            case "customer.subscription.created":
            case "customer.subscription.updated":
                await syncSubscriptionToFirestore(event.data.object);
                break;
            case "customer.subscription.deleted":
                await markSubscriptionCanceled(event.data.object);
                break;
            case "invoice.paid":
                await syncInvoiceToFirestore(event.data.object, "paid");
                break;
            case "invoice.payment_failed":
                await syncInvoiceToFirestore(event.data.object, "failed");
                break;
            default:
                // Événement non géré : on répond 200 pour éviter les tentatives
                // de retry inutiles de Stripe.
                break;
        }
        res.status(200).json({ ok: true });
    }
    catch (error) {
        logger_1.logger.error("stripe_webhook_processing_failed", {
            eventType: event.type,
            eventId: event.id,
            error: error instanceof Error ? error.message : String(error),
        });
        res.status(500).json({ ok: false });
    }
});
//# sourceMappingURL=webhook.js.map