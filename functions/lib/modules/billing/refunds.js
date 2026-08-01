"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DISPUTES_COLLECTION = exports.REFUNDS_COLLECTION = void 0;
exports.normalizedRefundStatus = normalizedRefundStatus;
exports.disputeOutcome = disputeOutcome;
exports.refundedAmountFromCharge = refundedAmountFromCharge;
exports.isFullRefund = isFullRefund;
exports.requiresBillingReview = requiresBillingReview;
exports.syncRefund = syncRefund;
exports.syncDispute = syncDispute;
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
exports.REFUNDS_COLLECTION = "billing_refunds";
exports.DISPUTES_COLLECTION = "billing_disputes";
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
/**
 * Statut de remboursement ramené à un vocabulaire stable.
 *
 * Stripe distingue `refund.failed` (l'événement) de `status: "failed"` (l'objet)
 * et n'envoie pas toujours les deux ensemble : le type d'événement fait foi
 * lorsqu'il est explicite, sinon on retombe sur le statut porté par l'objet.
 */
function normalizedRefundStatus(eventType, refund) {
    if (eventType === "refund.failed")
        return "failed";
    switch (asString(refund.status).toLowerCase()) {
        case "succeeded":
            return "succeeded";
        case "failed":
            return "failed";
        case "canceled":
        case "cancelled":
            return "canceled";
        case "pending":
        case "requires_action":
            return "pending";
        default:
            // `charge.refunded` porte la charge, pas le remboursement : à ce stade
            // Stripe a déjà débité le compte, le remboursement est acquis.
            return eventType === "charge.refunded" ? "succeeded" : "pending";
    }
}
/**
 * Issue d'un litige, du point de vue du commerçant.
 *
 * `warning_*` couvre les alertes émises par le réseau avant tout litige
 * formel : aucune somme n'est encore retenue, mais l'incident doit être visible.
 */
function disputeOutcome(eventType, dispute) {
    const status = asString(dispute.status).toLowerCase();
    if (status.startsWith("warning"))
        return "warning";
    if (status === "won")
        return "won";
    if (status === "lost")
        return "lost";
    if (eventType === "charge.dispute.funds_reinstated")
        return "won";
    if (eventType === "charge.dispute.funds_withdrawn")
        return "lost";
    return "open";
}
/**
 * Montant réellement remboursé sur une charge, en plus petite unité monétaire.
 *
 * `amount_refunded` est cumulatif : un remboursement partiel suivi d'un second
 * donne bien le total, il ne faut donc pas additionner les objets `refund`.
 */
function refundedAmountFromCharge(charge) {
    return Math.max(0, asNumber(charge.amount_refunded));
}
/** Un remboursement total libère l'accès ; un remboursement partiel non. */
function isFullRefund(charge) {
    const amount = asNumber(charge.amount);
    const refunded = refundedAmountFromCharge(charge);
    return amount > 0 && refunded >= amount;
}
/**
 * Décide si un incident de paiement doit lever une alerte de facturation sur
 * le compte utilisateur.
 *
 * Volontairement conservateur : un litige perdu ou un remboursement total
 * signalent le compte pour revue humaine, mais **aucune révocation
 * automatique des droits n'est appliquée ici**. Couper un accès payant sur la
 * foi d'un webhook est une décision commerciale, pas technique, et une
 * réouverture de litige gagnée devrait alors être rejouée à l'envers.
 */
function requiresBillingReview(kind, outcome) {
    if (kind === "dispute")
        return ["open", "lost", "warning"].includes(outcome);
    return outcome === "succeeded";
}
async function syncRefund(refund, context) {
    const refundId = asString(refund.id);
    if (!refundId)
        return;
    const charge = asMap(context.charge);
    const status = normalizedRefundStatus(context.eventType, refund);
    const data = {
        stripe_refund_id: refundId,
        stripe_charge_id: asString(refund.charge || charge.id),
        stripe_payment_intent_id: asString(refund.payment_intent || charge.payment_intent),
        stripe_invoice_id: asString(charge.invoice),
        user_id: context.userId,
        status,
        reason: asString(refund.reason),
        amount: asNumber(refund.amount),
        charge_amount: asNumber(charge.amount),
        charge_amount_refunded: refundedAmountFromCharge(charge),
        full_refund: isFullRefund(charge),
        currency: asString(refund.currency || charge.currency || "eur").toUpperCase(),
        refunded_at: unixMs(refund.created),
        requires_review: requiresBillingReview("refund", status),
        last_stripe_event_id: context.eventId,
        last_stripe_event_created_at: context.eventCreatedAtMs,
        stripe_updated_at: firestore_1.FieldValue.serverTimestamp(),
    };
    await firestore_2.db.collection(exports.REFUNDS_COLLECTION).doc(refundId).set(data, { merge: true });
    await flagUserBilling(context.userId, {
        kind: "refund",
        reference: refundId,
        state: status,
        requiresReview: data.requires_review,
        eventId: context.eventId,
    });
}
async function syncDispute(dispute, context) {
    const disputeId = asString(dispute.id);
    if (!disputeId)
        return;
    const outcome = disputeOutcome(context.eventType, dispute);
    const evidenceDetails = asMap(dispute.evidence_details);
    const data = {
        stripe_dispute_id: disputeId,
        stripe_charge_id: asString(dispute.charge),
        stripe_payment_intent_id: asString(dispute.payment_intent),
        user_id: context.userId,
        outcome,
        status: asString(dispute.status),
        reason: asString(dispute.reason),
        amount: asNumber(dispute.amount),
        currency: asString(dispute.currency || "eur").toUpperCase(),
        // Échéance de contestation : au-delà, la banque tranche sans nous.
        evidence_due_by: unixMs(evidenceDetails.due_by),
        evidence_submitted: evidenceDetails.submission_count
            ? asNumber(evidenceDetails.submission_count) > 0
            : false,
        opened_at: unixMs(dispute.created),
        requires_review: requiresBillingReview("dispute", outcome),
        last_stripe_event_id: context.eventId,
        last_stripe_event_created_at: context.eventCreatedAtMs,
        stripe_updated_at: firestore_1.FieldValue.serverTimestamp(),
    };
    await firestore_2.db.collection(exports.DISPUTES_COLLECTION).doc(disputeId).set(data, { merge: true });
    await flagUserBilling(context.userId, {
        kind: "dispute",
        reference: disputeId,
        state: outcome,
        requiresReview: data.requires_review,
        eventId: context.eventId,
    });
}
async function flagUserBilling(userId, incident) {
    if (!userId)
        return;
    const userRef = firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId);
    const snapshot = await userRef.get();
    if (!snapshot.exists)
        return;
    await userRef.set({
        billingIncident: {
            kind: incident.kind,
            reference: incident.reference,
            state: incident.state,
            requiresReview: incident.requiresReview,
            lastStripeEventId: incident.eventId,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        },
    }, { merge: true });
}
//# sourceMappingURL=refunds.js.map