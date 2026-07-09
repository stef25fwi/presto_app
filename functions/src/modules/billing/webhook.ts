import admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import type Stripe from "stripe";
import {
  PROJECT_REGION,
  STRIPE_PRICE_ILIPRESTO_PLUS,
  STRIPE_PRICE_ILIPRO,
  STRIPE_SECRETS,
  STRIPE_WEBHOOK_SECRET,
} from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";
import { getStripeClient } from "./stripe_client";

type InternalPlanKey = "free" | "ilipresto_plus" | "ilipro";
type InternalStatusKey = "inactive" | "active" | "past_due" | "canceled";

function resolvePlanForPriceId(priceId: string | undefined): InternalPlanKey {
  if (!priceId) return "free";
  if (priceId === STRIPE_PRICE_ILIPRESTO_PLUS) return "ilipresto_plus";
  if (priceId === STRIPE_PRICE_ILIPRO) return "ilipro";
  return "free";
}

function resolveInternalStatus(stripeStatus: Stripe.Subscription.Status): InternalStatusKey {
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

async function resolveUserIdForCustomer(
  customerId: string,
  metadataUserId?: string | null,
): Promise<string | null> {
  const fromMetadata = String(metadataUserId || "").trim();
  if (fromMetadata) return fromMetadata;

  const snap = await db
    .collection(COLLECTIONS.users)
    .where("stripeCustomerId", "==", customerId)
    .limit(1)
    .get();
  const doc = snap.docs[0];
  return doc ? doc.id : null;
}

async function syncSubscriptionToFirestore(subscription: Stripe.Subscription): Promise<void> {
  const customerId = typeof subscription.customer === "string"
    ? subscription.customer
    : subscription.customer.id;
  const userId = await resolveUserIdForCustomer(customerId, subscription.metadata?.userId);
  if (!userId) {
    logger.warn("stripe_webhook_unresolved_customer", { customerId, subscriptionId: subscription.id });
    return;
  }

  const priceId = subscription.items.data[0]?.price?.id;
  const plan = resolvePlanForPriceId(priceId);
  const internalStatus = resolveInternalStatus(subscription.status);
  const currentPeriodEndMs = subscription.items.data[0]?.current_period_end
    ? subscription.items.data[0].current_period_end * 1000
    : Date.now();
  const isActivePlan = internalStatus === "active";

  await db.collection(COLLECTIONS.subscriptions).doc(subscription.id).set(
    {
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
    },
    { merge: true },
  );

  await db.collection(COLLECTIONS.users).doc(userId).set(
    {
      subscriptionPlan: isActivePlan ? plan : "free",
      subscriptionStatus: internalStatus,
      subscriptionExpiresAt: admin.firestore.Timestamp.fromMillis(currentPeriodEndMs),
      stripeCustomerId: customerId,
    },
    { merge: true },
  );
}

async function markSubscriptionCanceled(subscription: Stripe.Subscription): Promise<void> {
  const customerId = typeof subscription.customer === "string"
    ? subscription.customer
    : subscription.customer.id;
  const userId = await resolveUserIdForCustomer(customerId, subscription.metadata?.userId);
  if (!userId) return;

  await db.collection(COLLECTIONS.subscriptions).doc(subscription.id).set(
    {
      user_id: userId,
      status: "canceled",
      stripe_status: subscription.status,
      updated_at: Date.now(),
    },
    { merge: true },
  );

  await db.collection(COLLECTIONS.users).doc(userId).set(
    {
      subscriptionPlan: "free",
      subscriptionStatus: "canceled",
    },
    { merge: true },
  );
}

async function syncInvoiceToFirestore(
  invoice: Stripe.Invoice,
  status: "paid" | "failed",
): Promise<void> {
  const customerId = typeof invoice.customer === "string"
    ? invoice.customer
    : invoice.customer?.id;
  if (!customerId) return;

  const userId = await resolveUserIdForCustomer(customerId, undefined);
  if (!userId) {
    logger.warn("stripe_webhook_invoice_unresolved_customer", { customerId, invoiceId: invoice.id });
    return;
  }

  await db.collection(COLLECTIONS.billingInvoices).doc(invoice.id).set(
    {
      user_id: userId,
      stripe_customer_id: customerId,
      status,
      amount_due: invoice.amount_due,
      amount_paid: invoice.amount_paid,
      currency: invoice.currency,
      updated_at: Date.now(),
    },
    { merge: true },
  );
}

export { resolvePlanForPriceId, resolveInternalStatus };

export const stripeWebhook = onRequest(
  { region: PROJECT_REGION, secrets: STRIPE_SECRETS },
  async (req, res) => {
    const signature = req.headers["stripe-signature"];
    if (!signature || typeof signature !== "string") {
      res.status(400).send("Missing Stripe-Signature header");
      return;
    }

    const stripe = getStripeClient();
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        signature,
        STRIPE_WEBHOOK_SECRET.value(),
      );
    } catch (error) {
      logger.warn("stripe_webhook_invalid_signature", {
        error: error instanceof Error ? error.message : String(error),
      });
      res.status(400).send("Invalid signature");
      return;
    }

    try {
      switch (event.type) {
        case "customer.subscription.created":
        case "customer.subscription.updated":
          await syncSubscriptionToFirestore(event.data.object as Stripe.Subscription);
          break;
        case "customer.subscription.deleted":
          await markSubscriptionCanceled(event.data.object as Stripe.Subscription);
          break;
        case "invoice.paid":
          await syncInvoiceToFirestore(event.data.object as Stripe.Invoice, "paid");
          break;
        case "invoice.payment_failed":
          await syncInvoiceToFirestore(event.data.object as Stripe.Invoice, "failed");
          break;
        default:
          // Événement non géré : on répond 200 pour éviter les tentatives
          // de retry inutiles de Stripe.
          break;
      }

      res.status(200).json({ ok: true });
    } catch (error) {
      logger.error("stripe_webhook_processing_failed", {
        eventType: event.type,
        eventId: event.id,
        error: error instanceof Error ? error.message : String(error),
      });
      res.status(500).json({ ok: false });
    }
  },
);
