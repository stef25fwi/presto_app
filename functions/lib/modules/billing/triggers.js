"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onBillingInvoiceUpdated = exports.onSubscriptionUpdated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
function extractFirstName(userData) {
    return String(userData?.display_name || userData?.displayName || "").trim().split(" ")[0] || "";
}
function normalizeStatus(value) {
    return String(value || "").trim().toLowerCase();
}
async function emitSubscriptionEvent({ eventId, eventName, subscriptionId, userId, dedupeSeed, occurredAt, payload, }) {
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: constants_1.COLLECTIONS.subscriptions,
        source_id: subscriptionId,
        recipient_user_id: userId,
        dedupe_key: (0, hash_1.sha256)(dedupeSeed),
        occurred_at: occurredAt,
        payload,
        status: "created",
    }, { merge: true });
}
exports.onSubscriptionUpdated = (0, firestore_1.onDocumentUpdated)(`${constants_1.COLLECTIONS.subscriptions}/{subscriptionId}`, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after)
        return;
    const userId = String(after.user_id || "");
    if (!userId)
        return;
    const renewalTs = Number(after.renewal_at || after.current_period_end || 0);
    if (!renewalTs)
        return;
    const now = Date.now();
    const in3Days = now + 3 * 24 * 60 * 60 * 1000;
    const beforeRenewal = Number(before?.renewal_at || before?.current_period_end || 0);
    const wasUpcoming = beforeRenewal >= now && beforeRenewal <= in3Days;
    const isUpcoming = renewalTs >= now && renewalTs <= in3Days;
    // Emit only on transition into the upcoming window.
    if (wasUpcoming || !isUpcoming)
        return;
    const userSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const userData = (userSnap.data() ?? {});
    const email = String(userData?.email || "").trim();
    if (!email)
        return;
    const subscriptionId = event.params.subscriptionId;
    const firstName = extractFirstName(userData);
    const afterStatus = normalizeStatus(after.status || after.subscription_status);
    const beforeStatus = normalizeStatus(before?.status || before?.subscription_status);
    if (beforeRenewal > 0 && renewalTs > beforeRenewal && afterStatus !== "expired" && afterStatus !== "cancelled") {
        await emitSubscriptionEvent({
            eventId: `evt_billing_subscription_renewed_${subscriptionId}_${Math.floor(renewalTs / 1000)}`,
            eventName: "billing.subscription.renewed",
            subscriptionId,
            userId,
            dedupeSeed: `billing.subscription.renewed:${subscriptionId}:${Math.floor(renewalTs / 1000)}`,
            occurredAt: now,
            payload: {
                recipient_email: email,
                firstName,
                renewalDate: new Date(renewalTs).toLocaleDateString("fr-FR"),
                planName: String(after.plan_name || after.plan || "PRESTO Premium"),
                manageUrl: `${env_1.APP_BASE_URL}/abonnement`,
            },
        });
    }
    if (beforeStatus !== afterStatus && (afterStatus === "expired" || afterStatus === "ended" || afterStatus === "cancelled")) {
        await emitSubscriptionEvent({
            eventId: `evt_billing_subscription_expired_${subscriptionId}_${Math.floor(now / 1000)}`,
            eventName: "billing.subscription.expired",
            subscriptionId,
            userId,
            dedupeSeed: `billing.subscription.expired:${subscriptionId}:${afterStatus}`,
            occurredAt: now,
            payload: {
                recipient_email: email,
                firstName,
                planName: String(after.plan_name || after.plan || "PRESTO Premium"),
                reactivateUrl: `${env_1.APP_BASE_URL}/abonnement`,
            },
        });
    }
    const eventId = `evt_subscription_renewal_upcoming_${subscriptionId}_${Math.floor(renewalTs / 1000)}`;
    const eventRef = firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId);
    if ((await eventRef.get()).exists)
        return;
    await eventRef.set({
        event_id: eventId,
        event_name: "subscription.renewal.upcoming",
        source_collection: constants_1.COLLECTIONS.subscriptions,
        source_id: subscriptionId,
        recipient_user_id: userId,
        dedupe_key: (0, hash_1.sha256)(`subscription.renewal.upcoming:${subscriptionId}:${Math.floor(renewalTs / 1000)}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            firstName,
            renewalDate: new Date(renewalTs).toLocaleDateString("fr-FR"),
            planName: String(after.plan_name || after.plan || "PRESTO Premium"),
            currency: String(after.currency || "EUR"),
            paymentMethod: String(after.payment_method_label || after.payment_method || after.method || ""),
            manageUrl: `${env_1.APP_BASE_URL}/abonnement`,
        },
        status: "created",
    });
});
exports.onBillingInvoiceUpdated = (0, firestore_1.onDocumentUpdated)(`${constants_1.COLLECTIONS.billingInvoices}/{invoiceId}`, async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after)
        return;
    const beforeStatus = String(before.status || "");
    const afterStatus = String(after.status || "");
    if (beforeStatus === afterStatus)
        return;
    const userId = String(after.user_id || "");
    if (!userId)
        return;
    const userSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const userData = userSnap.data();
    const email = String(userData?.email || "").trim();
    if (!email)
        return;
    const invoiceId = event.params.invoiceId;
    const now = Date.now();
    if (afterStatus === "failed" || afterStatus === "payment_failed") {
        const eventId = `evt_billing_payment_failed_${invoiceId}_${now}`;
        await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "billing.payment.failed",
            source_collection: constants_1.COLLECTIONS.billingInvoices,
            source_id: invoiceId,
            recipient_user_id: userId,
            dedupe_key: (0, hash_1.sha256)(`billing.payment.failed:${invoiceId}:${afterStatus}`),
            occurred_at: now,
            payload: {
                recipient_email: email,
                firstName: String(userData?.display_name || userData?.displayName || "").split(" ")[0] ?? "",
                amount: Number(after.amount_due || after.amount || 0),
                currency: String(after.currency || "EUR"),
                paymentMethod: String(after.payment_method_label || after.payment_method || after.method || ""),
                nextRetryAt: Number(after.next_retry_at || after.retry_at || 0) || undefined,
                retryUrl: `${env_1.APP_BASE_URL}/facturation`,
            },
            status: "created",
        });
        return;
    }
    if (afterStatus === "paid" || afterStatus === "succeeded" || afterStatus === "payment_succeeded") {
        const eventId = `evt_billing_payment_succeeded_${invoiceId}_${now}`;
        await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "billing.payment.succeeded",
            source_collection: constants_1.COLLECTIONS.billingInvoices,
            source_id: invoiceId,
            recipient_user_id: userId,
            dedupe_key: (0, hash_1.sha256)(`billing.payment.succeeded:${invoiceId}:${afterStatus}`),
            occurred_at: now,
            payload: {
                recipient_email: email,
                firstName: String(userData?.display_name || userData?.displayName || "").split(" ")[0] ?? "",
                amount: Number(after.amount_paid || after.amount_due || after.amount || 0),
                currency: String(after.currency || "EUR"),
                paymentMethod: String(after.payment_method_label || after.payment_method || after.method || ""),
                invoiceUrl: `${env_1.APP_BASE_URL}/facturation`,
            },
            status: "created",
        });
    }
});
//# sourceMappingURL=triggers.js.map