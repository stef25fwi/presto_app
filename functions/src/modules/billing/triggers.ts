import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

export const onSubscriptionUpdated = onDocumentUpdated(`${COLLECTIONS.subscriptions}/{subscriptionId}`, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return;

  const userId = String(after.user_id || "");
  if (!userId) return;

  const renewalTs = Number(after.renewal_at || after.current_period_end || 0);
  if (!renewalTs) return;

  const now = Date.now();
  const in3Days = now + 3 * 24 * 60 * 60 * 1000;

  const beforeRenewal = Number(before?.renewal_at || before?.current_period_end || 0);
  const wasUpcoming = beforeRenewal >= now && beforeRenewal <= in3Days;
  const isUpcoming = renewalTs >= now && renewalTs <= in3Days;

  // Emit only on transition into the upcoming window.
  if (wasUpcoming || !isUpcoming) return;

  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const userData = userSnap.data();
  const email = String(userData?.email || "").trim();
  if (!email) return;

  const subscriptionId = event.params.subscriptionId;
  const eventId = `evt_subscription_renewal_upcoming_${subscriptionId}_${Math.floor(renewalTs / 1000)}`;
  const eventRef = db.collection(COLLECTIONS.emailEvents).doc(eventId);
  if ((await eventRef.get()).exists) return;

  await eventRef.set({
    event_id: eventId,
    event_name: "subscription.renewal.upcoming",
    source_collection: COLLECTIONS.subscriptions,
    source_id: subscriptionId,
    recipient_user_id: userId,
    dedupe_key: sha256(`subscription.renewal.upcoming:${subscriptionId}:${Math.floor(renewalTs / 1000)}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      firstName: String(userData?.display_name || userData?.displayName || "").split(" ")[0] ?? "",
      renewalDate: new Date(renewalTs).toLocaleDateString("fr-FR"),
      planName: String(after.plan_name || after.plan || "PRESTO Premium"),
      currency: String(after.currency || "EUR"),
      paymentMethod: String(after.payment_method_label || after.payment_method || after.method || ""),
      manageUrl: "https://presto.app/abonnement",
    },
    status: "created",
  });
});

export const onBillingInvoiceUpdated = onDocumentUpdated(`${COLLECTIONS.billingInvoices}/{invoiceId}`, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const beforeStatus = String(before.status || "");
  const afterStatus = String(after.status || "");
  if (beforeStatus === afterStatus) return;

  const userId = String(after.user_id || "");
  if (!userId) return;

  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const userData = userSnap.data();
  const email = String(userData?.email || "").trim();
  if (!email) return;

  const invoiceId = event.params.invoiceId;
  const now = Date.now();

  if (afterStatus === "failed" || afterStatus === "payment_failed") {
    const eventId = `evt_billing_payment_failed_${invoiceId}_${now}`;

    await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
      event_id: eventId,
      event_name: "billing.payment.failed",
      source_collection: COLLECTIONS.billingInvoices,
      source_id: invoiceId,
      recipient_user_id: userId,
      dedupe_key: sha256(`billing.payment.failed:${invoiceId}:${afterStatus}`),
      occurred_at: now,
      payload: {
        recipient_email: email,
        firstName: String(userData?.display_name || userData?.displayName || "").split(" ")[0] ?? "",
        amount: Number(after.amount_due || after.amount || 0),
        currency: String(after.currency || "EUR"),
        paymentMethod: String(after.payment_method_label || after.payment_method || after.method || ""),
        nextRetryAt: Number(after.next_retry_at || after.retry_at || 0) || undefined,
        retryUrl: "https://presto.app/facturation",
      },
      status: "created",
    });
    return;
  }

  if (afterStatus === "paid" || afterStatus === "succeeded" || afterStatus === "payment_succeeded") {
    const eventId = `evt_billing_payment_succeeded_${invoiceId}_${now}`;

    await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
      event_id: eventId,
      event_name: "billing.payment.succeeded",
      source_collection: COLLECTIONS.billingInvoices,
      source_id: invoiceId,
      recipient_user_id: userId,
      dedupe_key: sha256(`billing.payment.succeeded:${invoiceId}:${afterStatus}`),
      occurred_at: now,
      payload: {
        recipient_email: email,
        firstName: String(userData?.display_name || userData?.displayName || "").split(" ")[0] ?? "",
        amount: Number(after.amount_paid || after.amount_due || after.amount || 0),
        currency: String(after.currency || "EUR"),
        paymentMethod: String(after.payment_method_label || after.payment_method || after.method || ""),
        invoiceUrl: "https://presto.app/facturation",
      },
      status: "created",
    });
  }
});
