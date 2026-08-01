import { FieldValue } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

import {
  PROJECT_REGION,
  STRIPE_CHECKOUT_SECRETS,
  STRIPE_SECRET_KEY,
} from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { stripeModeFromSecret } from "./stripe_mode";

type JsonMap = Record<string, unknown>;

export const RECONCILIATION_COLLECTION = "billing_reconciliation_reports";

/** Nombre d'abonnements ramenés par appel : plafond de l'API Stripe. */
const PAGE_SIZE = 100;

/** Garde-fou : au-delà, on s'arrête et on le signale plutôt que de boucler. */
const MAX_PAGES = 50;

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

export type Divergence = {
  subscriptionId: string;
  field: string;
  stripe: string;
  firestore: string;
};

/**
 * Compare un abonnement Stripe à sa copie Firestore.
 *
 * Les webhooks peuvent être perdus, rejoués dans le désordre ou traités
 * pendant une panne Firestore : sans recoupement périodique, un abonnement
 * annulé chez Stripe peut rester actif dans l'application indéfiniment. C'est
 * exactement ce type d'écart que cette fonction met en évidence.
 *
 * `current_period_end` est comparé à la seconde près : Stripe l'exprime en
 * secondes, Firestore en millisecondes, et une différence d'arrondi n'est pas
 * une divergence.
 */
export function diffSubscriptionRecord(
  stripeSubscription: JsonMap,
  storedData: JsonMap | undefined,
): Divergence[] {
  const subscriptionId = asString(stripeSubscription.id);
  const divergences: Divergence[] = [];

  if (!storedData) {
    return [{
      subscriptionId,
      field: "document",
      stripe: "présent",
      firestore: "absent",
    }];
  }

  const stripeStatus = asString(stripeSubscription.status).toLowerCase();
  const storedStatus = asString(storedData.status).toLowerCase();
  if (stripeStatus !== storedStatus) {
    divergences.push({
      subscriptionId,
      field: "status",
      stripe: stripeStatus,
      firestore: storedStatus,
    });
  }

  const stripeCancel = stripeSubscription.cancel_at_period_end === true;
  const storedCancel = storedData.cancel_at_period_end === true;
  if (stripeCancel !== storedCancel) {
    divergences.push({
      subscriptionId,
      field: "cancel_at_period_end",
      stripe: String(stripeCancel),
      firestore: String(storedCancel),
    });
  }

  const stripePeriodEndSeconds = asNumber(stripeSubscription.current_period_end);
  const storedPeriodEndSeconds = Math.floor(
    asNumber(storedData.current_period_end) / 1000,
  );
  if (
    stripePeriodEndSeconds > 0 &&
    stripePeriodEndSeconds !== storedPeriodEndSeconds
  ) {
    divergences.push({
      subscriptionId,
      field: "current_period_end",
      stripe: String(stripePeriodEndSeconds),
      firestore: String(storedPeriodEndSeconds),
    });
  }

  const items = asMap(stripeSubscription.items);
  const rows = Array.isArray(items.data) ? items.data : [];
  const stripePriceId = asString(asMap(asMap(rows[0]).price).id);
  const storedPriceId = asString(storedData.stripe_price_id);
  if (stripePriceId && stripePriceId !== storedPriceId) {
    divergences.push({
      subscriptionId,
      field: "stripe_price_id",
      stripe: stripePriceId,
      firestore: storedPriceId,
    });
  }

  return divergences;
}

export type ReconciliationSummary = {
  scanned: number;
  diverging: number;
  divergences: Divergence[];
  truncated: boolean;
};

export function summarize(
  results: Divergence[][],
  truncated: boolean,
): ReconciliationSummary {
  const divergences = results.flat();
  const subjects = new Set(divergences.map((item) => item.subscriptionId));
  return {
    scanned: results.length,
    diverging: subjects.size,
    divergences,
    truncated,
  };
}

async function stripeGet(path: string, secret: string): Promise<JsonMap> {
  const response = await fetch(`https://api.stripe.com${path}`, {
    headers: { Authorization: `Bearer ${secret}` },
  });
  const data = await response.json().catch(() => ({})) as JsonMap;
  if (!response.ok) {
    const error = asMap(data.error);
    throw new Error(asString(error.message) || `Stripe API error ${response.status}`);
  }
  return data;
}

export async function reconcileOnce(): Promise<ReconciliationSummary> {
  const secret = STRIPE_SECRET_KEY.value().trim();
  if (!stripeModeFromSecret(secret)) {
    throw new Error("STRIPE_SECRET_KEY absente ou invalide");
  }

  const results: Divergence[][] = [];
  let startingAfter = "";
  let truncated = false;

  for (let page = 0; page < MAX_PAGES; page += 1) {
    const query = new URLSearchParams({ limit: String(PAGE_SIZE), status: "all" });
    if (startingAfter) query.set("starting_after", startingAfter);

    const payload = await stripeGet(`/v1/subscriptions?${query.toString()}`, secret);
    const rows = Array.isArray(payload.data) ? payload.data.map(asMap) : [];
    if (rows.length === 0) break;

    // Les lectures Firestore sont groupées par page pour ne pas émettre une
    // requête par abonnement.
    const refs = rows.map((subscription) =>
      db.collection(COLLECTIONS.subscriptions).doc(asString(subscription.id)));
    const snapshots = await db.getAll(...refs);

    rows.forEach((subscription, index) => {
      results.push(diffSubscriptionRecord(subscription, snapshots[index]?.data()));
    });

    startingAfter = asString(rows[rows.length - 1]?.id);
    if (payload.has_more !== true) break;
    if (page === MAX_PAGES - 1) truncated = true;
  }

  const summary = summarize(results, truncated);

  await db.collection(RECONCILIATION_COLLECTION).add({
    scanned: summary.scanned,
    diverging: summary.diverging,
    truncated: summary.truncated,
    // Le détail est borné : un rapport ne doit pas dépasser la taille d'un
    // document Firestore quand tout diverge.
    divergences: summary.divergences.slice(0, 200),
    stripe_mode: stripeModeFromSecret(secret),
    created_at: FieldValue.serverTimestamp(),
  });

  return summary;
}

/**
 * Recoupement quotidien Stripe ↔ Firestore.
 *
 * Volontairement en lecture seule : le job constate et journalise, il ne
 * réécrit pas les abonnements. Une correction automatique sur la foi d'un
 * écart transitoire (webhook en vol, réplication Firestore en retard) ferait
 * plus de dégâts que l'écart lui-même. Le rapport sert de point de départ à
 * une reprise manuelle ou à un rejeu de webhook depuis le dashboard Stripe.
 */
export const reconcileStripeSubscriptions = onSchedule({
  region: PROJECT_REGION,
  schedule: "every day 03:30",
  timeZone: "UTC",
  secrets: STRIPE_CHECKOUT_SECRETS,
  timeoutSeconds: 540,
  memory: "512MiB",
}, async () => {
  try {
    const summary = await reconcileOnce();
    if (summary.diverging > 0) {
      console.warn("STRIPE_RECONCILIATION_DIVERGENCE", {
        scanned: summary.scanned,
        diverging: summary.diverging,
        truncated: summary.truncated,
        sample: summary.divergences.slice(0, 10),
      });
    } else {
      console.log("STRIPE_RECONCILIATION_OK", { scanned: summary.scanned });
    }
  } catch (error) {
    console.error("STRIPE_RECONCILIATION_ERROR", error);
    throw error;
  }
});
