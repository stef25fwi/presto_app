"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.reconcileStripeSubscriptions = exports.RECONCILIATION_COLLECTION = void 0;
exports.diffSubscriptionRecord = diffSubscriptionRecord;
exports.summarize = summarize;
exports.reconcileOnce = reconcileOnce;
const firestore_1 = require("firebase-admin/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../config/env");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const stripe_mode_1 = require("./stripe_mode");
exports.RECONCILIATION_COLLECTION = "billing_reconciliation_reports";
/** Nombre d'abonnements ramenés par appel : plafond de l'API Stripe. */
const PAGE_SIZE = 100;
/** Garde-fou : au-delà, on s'arrête et on le signale plutôt que de boucler. */
const MAX_PAGES = 50;
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
function diffSubscriptionRecord(stripeSubscription, storedData) {
    const subscriptionId = asString(stripeSubscription.id);
    const divergences = [];
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
    const storedPeriodEndSeconds = Math.floor(asNumber(storedData.current_period_end) / 1000);
    if (stripePeriodEndSeconds > 0 &&
        stripePeriodEndSeconds !== storedPeriodEndSeconds) {
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
function summarize(results, truncated) {
    const divergences = results.flat();
    const subjects = new Set(divergences.map((item) => item.subscriptionId));
    return {
        scanned: results.length,
        diverging: subjects.size,
        divergences,
        truncated,
    };
}
async function stripeGet(path, secret) {
    const response = await fetch(`https://api.stripe.com${path}`, {
        headers: { Authorization: `Bearer ${secret}` },
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        const error = asMap(data.error);
        throw new Error(asString(error.message) || `Stripe API error ${response.status}`);
    }
    return data;
}
async function reconcileOnce() {
    const secret = env_1.STRIPE_SECRET_KEY.value().trim();
    if (!(0, stripe_mode_1.stripeModeFromSecret)(secret)) {
        throw new Error("STRIPE_SECRET_KEY absente ou invalide");
    }
    const results = [];
    let startingAfter = "";
    let truncated = false;
    for (let page = 0; page < MAX_PAGES; page += 1) {
        const query = new URLSearchParams({ limit: String(PAGE_SIZE), status: "all" });
        if (startingAfter)
            query.set("starting_after", startingAfter);
        const payload = await stripeGet(`/v1/subscriptions?${query.toString()}`, secret);
        const rows = Array.isArray(payload.data) ? payload.data.map(asMap) : [];
        if (rows.length === 0)
            break;
        // Les lectures Firestore sont groupées par page pour ne pas émettre une
        // requête par abonnement.
        const refs = rows.map((subscription) => firestore_2.db.collection(constants_1.COLLECTIONS.subscriptions).doc(asString(subscription.id)));
        const snapshots = await firestore_2.db.getAll(...refs);
        rows.forEach((subscription, index) => {
            results.push(diffSubscriptionRecord(subscription, snapshots[index]?.data()));
        });
        startingAfter = asString(rows[rows.length - 1]?.id);
        if (payload.has_more !== true)
            break;
        if (page === MAX_PAGES - 1)
            truncated = true;
    }
    const summary = summarize(results, truncated);
    await firestore_2.db.collection(exports.RECONCILIATION_COLLECTION).add({
        scanned: summary.scanned,
        diverging: summary.diverging,
        truncated: summary.truncated,
        // Le détail est borné : un rapport ne doit pas dépasser la taille d'un
        // document Firestore quand tout diverge.
        divergences: summary.divergences.slice(0, 200),
        stripe_mode: (0, stripe_mode_1.stripeModeFromSecret)(secret),
        created_at: firestore_1.FieldValue.serverTimestamp(),
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
exports.reconcileStripeSubscriptions = (0, scheduler_1.onSchedule)({
    region: env_1.PROJECT_REGION,
    schedule: "every day 03:30",
    timeZone: "UTC",
    secrets: env_1.STRIPE_CHECKOUT_SECRETS,
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
        }
        else {
            console.log("STRIPE_RECONCILIATION_OK", { scanned: summary.scanned });
        }
    }
    catch (error) {
        console.error("STRIPE_RECONCILIATION_ERROR", error);
        throw error;
    }
});
//# sourceMappingURL=reconciliation.js.map