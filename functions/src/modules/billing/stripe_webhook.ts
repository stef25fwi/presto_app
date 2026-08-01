import { createHmac, timingSafeEqual } from "crypto";
import { FieldValue } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import {
  PROJECT_REGION,
  STRIPE_PRICE_ILIPRESTO_PLUS,
  STRIPE_PRICE_ILIPRO,
  STRIPE_SECRET_KEY,
  STRIPE_WEBHOOK_SECRET,
} from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { syncDispute, syncRefund } from "./refunds";
import {
  describeModeMismatch,
  livemodeVerdict,
  stripeModeFromSecret,
  type StripeMode,
} from "./stripe_mode";

type JsonMap = Record<string, unknown>;
type SubscriptionPlan = "ilipresto_plus" | "ilipro";

type StripeEvent = {
  id: string;
  type: string;
  created?: number;
  livemode?: boolean;
  data?: { object?: JsonMap };
};

const WEBHOOK_EVENTS_COLLECTION = "stripe_webhook_events";
const SIGNATURE_TOLERANCE_SECONDS = 5 * 60;
const PROCESSING_LEASE_MS = 2 * 60 * 1000;

class WebhookSignatureError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WebhookSignatureError";
  }
}

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
  if (!value) throw new WebhookSignatureError("STRIPE_WEBHOOK_SECRET non configuré");
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

/**
 * Vérifie l'en-tête `Stripe-Signature` d'un corps brut.
 *
 * Le secret est lu à l'appel plutôt qu'injecté pour rester aligné sur le reste
 * du module ; `secretOverride` n'existe que pour les tests, qui n'ont pas de
 * secret Firebase à disposition.
 */
export function verifyStripeSignature(
  rawBody: Buffer,
  signatureHeader: string,
  secretOverride?: string,
): void {
  const secret = secretOverride ?? webhookSecret();
  const { timestamp, signatures } = parseStripeSignature(signatureHeader);
  if (!timestamp || signatures.length === 0) {
    throw new WebhookSignatureError("Signature Stripe absente ou invalide");
  }

  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) {
    throw new WebhookSignatureError("Horodatage Stripe invalide");
  }
  const age = Math.abs(Math.floor(Date.now() / 1000) - timestampSeconds);
  if (age > SIGNATURE_TOLERANCE_SECONDS) {
    throw new WebhookSignatureError("Signature Stripe expirée");
  }

  const signedPayload = `${timestamp}.${rawBody.toString("utf8")}`;
  const expected = createHmac("sha256", secret).update(signedPayload).digest("hex");
  if (!signatures.some((signature) => safeHexEqual(signature, expected))) {
    throw new WebhookSignatureError("Signature Stripe incorrecte");
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

function configuredPriceIds(): {
  plus: string[];
  pro: string[];
} {
  const plus = [
    STRIPE_PRICE_ILIPRESTO_PLUS.value(),
    process.env.STRIPE_PRICE_ILIPRESTO_PLUS,
    process.env.STRIPE_PRICE_ILIPRESTO_PLUS_MONTHLY,
    process.env.STRIPE_PRICE_ILIPRESTO,
  ].map(asString).filter(Boolean);
  const pro = [
    STRIPE_PRICE_ILIPRO.value(),
    process.env.STRIPE_PRICE_ILIPRO,
    process.env.STRIPE_PRICE_ILIPRO_MONTHLY,
  ].map(asString).filter(Boolean);
  return { plus: [...new Set(plus)], pro: [...new Set(pro)] };
}

export function planFromStripe(subscription: JsonMap): SubscriptionPlan | null {
  const metadata = asMap(subscription.metadata);
  const metadataPlan = asString(metadata.plan).toLowerCase();
  if (metadataPlan === "ilipro") return "ilipro";
  if (["ilipresto_plus", "iliprestoplus", "ilipresto+"].includes(metadataPlan)) {
    return "ilipresto_plus";
  }

  const priceId = priceIdFromSubscription(subscription);
  const prices = configuredPriceIds();
  if (prices.pro.includes(priceId)) return "ilipro";
  if (prices.plus.includes(priceId)) return "ilipresto_plus";
  return null;
}

export function appPlan(plan: SubscriptionPlan): string {
  return plan === "ilipresto_plus" ? "iliprestoPlus" : plan;
}

export function appStatus(rawStatus: string): "active" | "pastDue" | "canceled" | "inactive" {
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

export function isDeletedAccountStatus(value: unknown): boolean {
  return ["deletion_processing", "deleted"].includes(asString(value).toLowerCase());
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
  if (eventType === "invoice.payment_action_required") return "action_required";
  if (eventType === "invoice.marked_uncollectible") return "uncollectible";
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
  const resolvedPlan = planFromStripe(subscription);
  if (!resolvedPlan && normalizedStatus === "active") {
    throw new Error(
      `Plan Stripe inconnu pour l’abonnement actif ${subscriptionId} (${priceIdFromSubscription(subscription)})`,
    );
  }

  const storedPlan = resolvedPlan || "unknown";
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
    plan: storedPlan,
    plan_name: resolvedPlan === "ilipro"
      ? "ilipro"
      : resolvedPlan === "ilipresto_plus"
        ? "iliprestō+"
        : "Inconnu",
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
    subscriptionPlan:
      normalizedStatus === "active" && resolvedPlan ? appPlan(resolvedPlan) : "free",
    subscriptionStatus: normalizedStatus,
    subscriptionExpiresAt: currentPeriodEnd ? new Date(currentPeriodEnd) : null,
    subscriptionCancelAtPeriodEnd: cancelAtPeriodEnd,
    stripeUpdatedAt: FieldValue.serverTimestamp(),
    lastStripeEventId: eventId,
    lastStripeEventCreatedAt: eventCreatedAtMs,
  };

  const subscriptionRef = db.collection(COLLECTIONS.subscriptions).doc(subscriptionId);
  const userRef = db.collection(COLLECTIONS.users).doc(userId);

  await db.runTransaction(async (transaction) => {
    const [existing, userSnapshot] = await Promise.all([
      transaction.get(subscriptionRef),
      transaction.get(userRef),
    ]);
    const lastEventCreatedAt = asNumber(
      existing.data()?.last_stripe_event_created_at,
    );
    if (!shouldApplyStripeEvent(lastEventCreatedAt, eventCreatedAtMs)) return;

    const deletedAccount = isDeletedAccountStatus(userSnapshot.data()?.accountStatus);
    transaction.set(subscriptionRef, {
      ...subscriptionData,
      user_account_deleted: deletedAccount,
    }, { merge: true });

    // Un webhook tardif ne doit jamais restaurer les identifiants Stripe ou
    // l’abonnement d’un compte en cours de suppression ou déjà supprimé.
    if (!deletedAccount && userSnapshot.exists) {
      transaction.set(userRef, userData, { merge: true });
    }
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

  const subscriptionId = asString(invoice.subscription);
  let subscription: JsonMap | null = null;
  let userId = await findUserId(invoice);
  if (subscriptionId) {
    subscription = await stripeGet(`/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
    if (!userId) userId = await findUserId(subscription);
  }

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
    if (!shouldApplyStripeEvent(lastEventCreatedAt, eventCreatedAtMs)) return;
    transaction.set(invoiceRef, data, { merge: true });
  });

  if (subscription) {
    await syncSubscription(subscription, eventId, eventCreatedAtMs);
  }
}

async function markCheckoutSession(
  session: JsonMap,
  status: string,
  eventId: string,
  eventCreatedAtMs: number,
): Promise<void> {
  const sessionId = asString(session.id);
  if (!sessionId) return;
  await db.collection("stripe_checkout_sessions").doc(sessionId).set({
    stripe_session_status: status,
    payment_status: asString(session.payment_status),
    subscription_id: asString(session.subscription),
    customer_id: asString(session.customer),
    last_stripe_event_id: eventId,
    last_stripe_event_created_at: eventCreatedAtMs,
    updated_at: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function processEvent(event: StripeEvent): Promise<void> {
  const object = asMap(event.data?.object);
  const eventCreatedAtMs = asNumber(event.created) * 1000;
  switch (event.type) {
    case "checkout.session.completed":
    case "checkout.session.async_payment_succeeded": {
      await markCheckoutSession(object, "complete", event.id, eventCreatedAtMs);
      const subscriptionId = asString(object.subscription);
      if (subscriptionId) {
        const subscription = await stripeGet(`/v1/subscriptions/${encodeURIComponent(subscriptionId)}`);
        await syncSubscription(subscription, event.id, eventCreatedAtMs);
      }
      return;
    }
    case "checkout.session.async_payment_failed":
      await markCheckoutSession(object, "payment_failed", event.id, eventCreatedAtMs);
      return;
    case "checkout.session.expired":
      await markCheckoutSession(object, "expired", event.id, eventCreatedAtMs);
      return;
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
    case "customer.subscription.paused":
    case "customer.subscription.resumed":
    case "customer.subscription.pending_update_applied":
    case "customer.subscription.pending_update_expired":
      await syncSubscription(object, event.id, eventCreatedAtMs);
      return;
    case "invoice.created":
    case "invoice.finalized":
    case "invoice.paid":
    case "invoice.payment_succeeded":
    case "invoice.payment_failed":
    case "invoice.payment_action_required":
    case "invoice.marked_uncollectible":
    case "invoice.voided":
      await syncInvoice(object, event.id, event.type, eventCreatedAtMs);
      return;
    case "charge.refunded":
    case "charge.refund.updated":
    case "refund.created":
    case "refund.updated":
    case "refund.failed": {
      // `charge.*` porte la charge, `refund.*` porte le remboursement : on
      // ramène les deux à un couple (remboursement, charge) avant traitement.
      const isChargeEvent = event.type.startsWith("charge.refunded");
      const charge = isChargeEvent
        ? object
        : await chargeForRefund(object);
      const refund = isChargeEvent ? latestRefundOfCharge(object) : object;
      if (!asString(refund.id)) return;
      await syncRefund(refund, {
        eventId: event.id,
        eventType: event.type,
        eventCreatedAtMs,
        userId: await findUserId(charge),
        charge,
      });
      return;
    }
    case "charge.dispute.created":
    case "charge.dispute.updated":
    case "charge.dispute.closed":
    case "charge.dispute.funds_withdrawn":
    case "charge.dispute.funds_reinstated": {
      const chargeId = asString(object.charge);
      const charge = chargeId
        ? await stripeGet(`/v1/charges/${encodeURIComponent(chargeId)}`)
        : {};
      await syncDispute(object, {
        eventId: event.id,
        eventType: event.type,
        eventCreatedAtMs,
        userId: await findUserId(charge),
      });
      return;
    }
    default:
      return;
  }
}

/** Dernier remboursement attaché à une charge, le plus récent d'abord. */
export function latestRefundOfCharge(charge: JsonMap): JsonMap {
  const refunds = asMap(charge.refunds);
  const rows = Array.isArray(refunds.data) ? refunds.data : [];
  const sorted = rows
    .map(asMap)
    .sort((left, right) => asNumber(right.created) - asNumber(left.created));
  return sorted[0] ?? {};
}

async function chargeForRefund(refund: JsonMap): Promise<JsonMap> {
  const chargeId = asString(refund.charge);
  if (!chargeId) return {};
  return stripeGet(`/v1/charges/${encodeURIComponent(chargeId)}`);
}

export type LeaseResult = "process" | "duplicate" | "busy";

/**
 * Décide du sort d'un événement à partir de son état déjà enregistré.
 *
 * Stripe rejoue chaque événement jusqu'à obtenir un 2xx : c'est ici que se
 * joue l'idempotence d'entrée. Un événement déjà traité est un doublon ; un
 * événement en cours l'est aussi tant que le bail n'a pas expiré, ce qui évite
 * deux traitements concurrents sans bloquer définitivement si une exécution
 * meurt avant d'avoir libéré son bail.
 */
export function evaluateEventLease(
  existing: JsonMap | undefined,
  nowMs: number,
  leaseMs: number = PROCESSING_LEASE_MS,
): LeaseResult {
  const data = existing ?? {};
  if (data.status === "processed") return "duplicate";

  const processingStartedAtMs = asNumber(data.processing_started_at_ms);
  if (
    data.status === "processing" &&
    processingStartedAtMs > 0 &&
    nowMs - processingStartedAtMs < leaseMs
  ) {
    return "busy";
  }

  return "process";
}

async function acquireEventLease(event: StripeEvent): Promise<LeaseResult> {
  const eventRef = db.collection(WEBHOOK_EVENTS_COLLECTION).doc(event.id);
  const now = Date.now();
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(eventRef);
    const verdict = evaluateEventLease(snap.data(), now);
    if (verdict !== "process") return verdict;

    transaction.set(eventRef, {
      event_id: event.id,
      event_type: event.type,
      stripe_created_at: event.created ? event.created * 1000 : null,
      status: "processing",
      attempts: FieldValue.increment(1),
      processing_started_at_ms: now,
      received_at: FieldValue.serverTimestamp(),
      last_attempt_at: FieldValue.serverTimestamp(),
      error: FieldValue.delete(),
    }, { merge: true });
    return "process";
  });
}

export const handleStripeWebhook = onRequest({
  region: PROJECT_REGION,
  secrets: [
    STRIPE_SECRET_KEY,
    STRIPE_WEBHOOK_SECRET,
    STRIPE_PRICE_ILIPRESTO_PLUS,
    STRIPE_PRICE_ILIPRO,
  ],
  timeoutSeconds: 60,
  memory: "256MiB",
  maxInstances: 20,
}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).send("Method Not Allowed");
    return;
  }

  let event: StripeEvent;
  try {
    const rawBody = request.rawBody;
    const signature = asString(request.headers["stripe-signature"]);
    verifyStripeSignature(rawBody, signature);
    event = JSON.parse(rawBody.toString("utf8")) as StripeEvent;
    if (!event.id || !event.type) {
      throw new WebhookSignatureError("Événement Stripe invalide");
    }

    // Cloisonnement test/réel : un secret de webhook recopié d'un
    // environnement à l'autre produit une signature valide pour des données
    // du mauvais monde. Le drapeau `livemode` est la seule barrière restante.
    const keyMode: StripeMode = stripeModeFromSecret(STRIPE_SECRET_KEY.value()) ?? "test";
    if (livemodeVerdict(event.livemode, keyMode) === "mismatch") {
      throw new WebhookSignatureError(
        describeModeMismatch(event.livemode, keyMode),
      );
    }
  } catch (error) {
    console.error("STRIPE_WEBHOOK_REJECTED", error);
    response.status(400).send(
      error instanceof Error ? error.message : "Webhook Stripe invalide",
    );
    return;
  }

  const eventRef = db.collection(WEBHOOK_EVENTS_COLLECTION).doc(event.id);
  try {
    const lease = await acquireEventLease(event);
    if (lease === "duplicate") {
      response.status(200).json({ received: true, duplicate: true });
      return;
    }
    if (lease === "busy") {
      response.setHeader("Retry-After", "5");
      response.status(409).json({ received: false, retry: true });
      return;
    }

    await processEvent(event);
    await eventRef.set({
      status: "processed",
      processed_at: FieldValue.serverTimestamp(),
      processing_started_at_ms: FieldValue.delete(),
      error: FieldValue.delete(),
    }, { merge: true });

    response.status(200).json({ received: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Erreur interne Stripe";
    console.error("STRIPE_WEBHOOK_PROCESSING_ERROR", {
      eventId: event.id,
      eventType: event.type,
      error,
    });
    await eventRef.set({
      status: "failed",
      failed_at: FieldValue.serverTimestamp(),
      processing_started_at_ms: FieldValue.delete(),
      error: message.slice(0, 1000),
    }, { merge: true }).catch((writeError) => {
      console.error("STRIPE_WEBHOOK_FAILURE_LOG_ERROR", writeError);
    });
    // 500 déclenche les nouvelles tentatives Stripe. Les signatures invalides
    // sont les seules erreurs définitivement rejetées en 400 ci-dessus.
    response.status(500).send("Webhook Stripe temporairement non traité");
  }
});
