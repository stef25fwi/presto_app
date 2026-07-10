import { createHmac, timingSafeEqual } from "crypto";
import { onRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import {
  PROJECT_REGION,
  STRIPE_SECRET_KEY,
  STRIPE_WEBHOOK_SECRET,
} from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

type JsonMap = Record<string, unknown>;

type StripeEvent = {
  id: string;
  type: string;
  created?: number;
  data?: { object?: JsonMap };
};

const WEBHOOK_EVENTS_COLLECTION = "stripe_webhook_events";
const SIGNATURE_TOLERANCE_SECONDS = 5 * 60;

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as JsonMap
    : {};
}

function asString(value: unknown): string {
  return String(value ?? "").trim();
}

function asNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function unixMs(value: unknown): number | null {
  const seconds = asNumber(value);
  return seconds > 0 ? seconds * 1000 : null;
}

function webhookSecret(): string {
  const value = STRIPE_WEBHOOK_SECRET.value().trim();
  if (!value) throw new Error("STRIPE_WEBHOOK_SECRET non configuré");
  return value;
}

function stripeSecret(): string {
  const value = STRIPE_SECRET_KEY.value().trim();
  if (!value) throw new Error("STRIPE_SECRET_KEY non configurée");
  return value;
}

function parseStripeSignature(header: string): { timestamp: string; signatures: string[] } {
  const parts = header.split(",").map((part) => part.trim());
  const timestamp = parts.find((part) => part.startsWith("t="))?.slice(2) ?? "";
  const signatures = parts
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.slice(3))
    .filter(Boolean);
  return { timestamp, signatures };
}

function safeHexEqual(left: string, right: string): boolean {
  try {
    const leftBuffer = Buffer.from(left, "hex");
    const rightBuffer = Buffer.from(right, "hex");
    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
  } catch {
    return false;
  }
}

function verifyStripeSignature(rawBody: Buffer, signatureHeader: string): void {
  const { timestamp, signatures } = parseStripeSignature(signatureHeader);
  if (!timestamp || signatures.length === 0) throw new Error("Signature Stripe absente ou invalide");

  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) throw new Error("Horodatage Stripe invalide");
  const age = Math.abs(Math.floor(Date.now() / 1000) - timestampSeconds);
  if (age > SIGNATURE_TOLERANCE_SECONDS) throw new Error("Signature Stripe expirée");

  const signedPayload = `${timestamp}.${rawBody.toString("utf8")}`;
  const expected = createHmac("sha256", webhookSecret()).update(signedPayload).digest("hex");
  if (!signatures.some((signature) => safeHexEqual(signature, expected))) {
    throw new Error("Signature Stripe incorrecte");
  }
}

async function stripeGet(path: string): Promise<JsonMap> {
  const response = await fetch(`https://api.stripe.com${path}`, {
    headers: { Authorization: `Bearer ${stripeSecret()}` },
  });
  const data = await response.json().catch(() => ({})) as JsonMap;
  if (!response.ok) {
    const error = asMap(data.error);
    throw new Error(asString(error.message) || `Stripe API error ${response.status}`);
  }
  return data;
}

function priceIdFromSubscription(subscription: JsonMap): string {
  const items = asMap(subscription.items);
  const rows = Array.isArray(items.data) ? items.data : [];
  const first = asMap(rows[0]);
  return asString(asMap(first.price).id);
}

function planFromStripe(subscription: JsonMap): "ilipresto_plus" | "ilipro" | "free" {
  const metadata = asMap(subscription.metadata);
  const metadataPlan = asString(metadata.plan).toLowerCase();
  if (["ilipro"].includes(metadataPlan)) return "ilipro";
  if (["ilipresto_plus", "iliprestoplus", "ilipresto+"].includes(metadataPlan)) return "ilipresto_plus";

  const priceId = priceIdFromSubscription(subscription);
  const iliproPrices = [process.env.STRIPE_PRICE_ILIPRO, process.env.STRIPE_PRICE_ILIPRO_MONTHLY]
    .map(asString)
    .filter(Boolean);
  const plusPrices = [
    process.env.STRIPE_PRICE_ILIPRESTO_PLUS,
    process.env.STRIPE_PRICE_ILIPRESTO_PLUS_MONTHLY,
    process.env.STRIPE_PRICE_ILIPRESTO,
  ].map(asString).filter(Boolean);
  if (iliproPrices.includes(priceId)) return "ilipro";
  if (plusPrices.includes(priceId)) return "ilipresto_plus";
  return "free";
}

function appPlan(plan: "ilipresto_plus" | "ilipro" | "free"): string {
  return plan === "ilipresto_plus" ? "iliprestoPlus" : plan;
}

function appStatus(rawStatus: string): "active" | "pastDue" | "canceled" | "inactive" {
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

async function findUserId(object: JsonMap): Promise<string> {
  const metadata = asMap(object.metadata);
  const direct = asString(metadata.firebaseUid || object.client_reference_id);
  if (direct) return direct;

  const customerId = asString(object.customer);
  if (!customerId) return "";
  for (const field of ["stripeCustomerId", "stripe_customer_id"]) {
    const snap = await db.collection(COLLECTIONS.users).where(field, "==", customerId).limit(1).get();
    const firstDocument = snap.docs[0];
    if (firstDocument) return firstDocument.id;
  }
  return "";
}

export function shouldApplyStripeEvent(
  lastEventCreatedAt: number,
  incomingEventCreatedAt: number,
): boolean {
  return incomingEventCreatedAt <= 0 || lastEventCreatedAt <= incomingEventCreatedAt;
}

export function normalizedInvoiceStatus(eventType: string, invoice: JsonMap): string {
  if (eventType === "invoice.payment_failed") return "payment_failed";
  if (eventType === "invoice.payment_succeeded" || eventType === "invoice.paid") {
    return "paid";
  }
  return asString(invoice.status || (invoice.paid === true ? "paid" : "open"));
}

async function syncSubscription(
  subscription: JsonMap,
  eventId: string,
  eventCreatedAtMs: number,
): Promise<void> {
  const subscriptionId = asString(subscription.id);
  if (!subscriptionId) throw new Error("Abonnement Stripe sans identifiant");

  const userId = await findUserId(subscription);
  if (!userId) throw new Error(`Utilisateur Firebase introuvable pour ${subscriptionId}`);

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
    last_stripe_event_created_at: eventCreatedAtMs,
    stripe_updated_at: FieldValue.serverTimestamp(),
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
    stripeUpdatedAt: FieldValue.serverTimestamp(),
    lastStripeEventId: eventId,
    lastStripeEventCreatedAt: eventCreatedAtMs,
  };

  const subscriptionRef =
    db.collection(COLLECTIONS.subscriptions).doc(subscriptionId);
  const userRef = db.collection(COLLECTIONS.users).doc(userId);

  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(subscriptionRef);
    const lastEventCreatedAt = asNumber(
      existing.data()?.last_stripe_event_created_at,
    );
    if (!shouldApplyStripeEvent(lastEventCreatedAt, eventCreatedAtMs)) {
      return;
    }

    transaction.set(subscriptionRef, subscriptionData, { merge: true });
    transaction.set(userRef, userData, { merge: true });
  });
}

async function syncInvoice(
  invoice: JsonMap,
  eventId: string,
  eventType: string,
  eventCreatedAtMs: number,
): Promise<void> {
  const invoiceId = asString(invoice.id);
  if (!invoiceId) throw new Error("Facture Stripe sans identifiant");

  const userId = await findUserId(invoice);
  const subscriptionId = asString(invoice.subscription);
  const status = normalizedInvoiceStatus(eventType, invoice);
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
    last_stripe_event_created_at: eventCreatedAtMs,
    stripe_updated_at: FieldValue.serverTimestamp(),
  };

  const invoiceRef = db.collection(COLLECTIONS.billingInvoices).doc(invoiceId);
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(invoiceRef);
    const lastEventCreatedAt = asNumber(
      existing.data()?.last_stripe_event_created_at,
    );
    if (!shouldApplyStripeEvent(lastEventCreatedAt, eventCreatedAtMs)) {
      return;
    }
    transaction.set(invoiceRef, data, { merge: true });
  });

  if (subscriptionId) {
    const subscription = await stripeGet(`/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
    await syncSubscription(subscription, eventId, eventCreatedAtMs);
  }
}

async function processEvent(event: StripeEvent): Promise<void> {
  const object = asMap(event.data?.object);
  const eventCreatedAtMs = asNumber(event.created) * 1000;
  switch (event.type) {
    case "checkout.session.completed": {
      const subscriptionId = asString(object.subscription);
      if (subscriptionId) {
        const subscription = await stripeGet(`/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
        await syncSubscription(subscription, event.id, eventCreatedAtMs);
      }
      return;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
    case "customer.subscription.paused":
    case "customer.subscription.resumed":
      await syncSubscription(object, event.id, eventCreatedAtMs);
      return;
    case "invoice.created":
    case "invoice.finalized":
    case "invoice.paid":
    case "invoice.payment_succeeded":
    case "invoice.payment_failed":
    case "invoice.voided":
      await syncInvoice(object, event.id, event.type, eventCreatedAtMs);
      return;
    default:
      return;
  }
}

export const handleStripeWebhook = onRequest({
  region: PROJECT_REGION,
  secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
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

    const event = JSON.parse(rawBody.toString("utf8")) as StripeEvent;
    if (!event.id || !event.type) throw new Error("Événement Stripe invalide");

    const eventRef = db.collection(WEBHOOK_EVENTS_COLLECTION).doc(event.id);
    const shouldProcess = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(eventRef);
      if (snap.exists && snap.data()?.status === "processed") return false;
      transaction.set(eventRef, {
        event_id: event.id,
        event_type: event.type,
        stripe_created_at: event.created ? event.created * 1000 : null,
        status: "processing",
        attempts: FieldValue.increment(1),
        received_at: FieldValue.serverTimestamp(),
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
      processed_at: FieldValue.serverTimestamp(),
      error: FieldValue.delete(),
    }, { merge: true });

    response.status(200).json({ received: true });
  } catch (error) {
    console.error("STRIPE_WEBHOOK_ERROR", error);
    response.status(400).send(error instanceof Error ? error.message : "Webhook Stripe invalide");
  }
});
