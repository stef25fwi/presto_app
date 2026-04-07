import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { DomainEventPayload } from "../../../types/events";

export function buildBillingInvoiceEnrichment(
  source: Record<string, unknown>,
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const extra: Record<string, unknown> = {};
  if (!payload.amount) extra.amount = Number(source.amount_due ?? source.amount ?? 0);
  if (!payload.currency) extra.currency = String(source.currency ?? "EUR");
  if (!payload.paymentMethod) {
    extra.paymentMethod = String(source.payment_method_label ?? source.payment_method ?? source.method ?? "");
  }
  if (!payload.nextRetryAt) {
    const retryAt = Number(source.next_retry_at ?? source.retry_at ?? 0);
    if (retryAt > 0) extra.nextRetryAt = retryAt;
  }
  if (!payload.retryUrl) extra.retryUrl = "https://presto.app/facturation";
  return extra;
}

export function buildSubscriptionEnrichment(
  source: Record<string, unknown>,
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const extra: Record<string, unknown> = {};
  if (!payload.planName) extra.planName = String(source.plan_name ?? source.plan ?? "PRESTO Premium");
  if (!payload.currency) extra.currency = String(source.currency ?? "EUR");
  if (!payload.renewalDate) {
    const renewalTs = Number(source.renewal_at ?? source.current_period_end ?? 0);
    if (renewalTs > 0) {
      extra.renewalDate = new Date(renewalTs).toLocaleDateString("fr-FR");
    }
  }
  if (!payload.paymentMethod) {
    extra.paymentMethod = String(source.payment_method_label ?? source.payment_method ?? source.method ?? "");
  }
  if (!payload.manageUrl) extra.manageUrl = "https://presto.app/abonnement";
  return extra;
}

export async function enrichEventPayload(event: DomainEventPayload): Promise<DomainEventPayload> {
  const extra: Record<string, unknown> = { enriched_at: Date.now() };

  // Enrichissement depuis le profil utilisateur destinataire
  const recipientId = event.recipient_user_id;
  if (recipientId) {
    try {
      const userDoc = await db.collection(COLLECTIONS.users).doc(recipientId).get();
      if (userDoc.exists) {
        const u = userDoc.data() ?? {};
        if (!event.payload.recipient_email) extra.recipient_email = String(u.email ?? "");
        if (!event.payload.firstName) extra.firstName = String(u.display_name ?? u.displayName ?? "").split(" ")[0] ?? "";
        if (!event.payload.city) extra.city = String(u.city ?? "");
      }
    } catch {
      // best-effort
    }
  }

  // Enrichissement depuis le document source (annonce, conversation, ticket…)
  if (event.source_collection && event.source_id) {
    try {
      const sourceDoc = await db.collection(event.source_collection).doc(event.source_id).get();
      if (sourceDoc.exists) {
        const s = sourceDoc.data() ?? {};
        if (event.source_collection === COLLECTIONS.listings || event.source_collection === COLLECTIONS.offers) {
          if (!event.payload.listingTitle) extra.listingTitle = String(s.title ?? "");
          if (!event.payload.listingUrl) extra.listingUrl = `https://presto.app/offers/${event.source_id}`;
          if (!event.payload.city) extra.city = String(s.city ?? extra.city ?? "");
        } else if (event.source_collection === COLLECTIONS.conversations) {
          if (!event.payload.conversationUrl) extra.conversationUrl = `https://presto.app/messages/${event.source_id}`;
          if (!event.payload.listingTitle) extra.listingTitle = String(s.offerTitle ?? s.listingTitle ?? s.title ?? "");
        } else if (event.source_collection === COLLECTIONS.supportTickets) {
          if (!event.payload.ticketNumber) extra.ticketNumber = String(s.ticket_number ?? event.source_id);
          if (!event.payload.ticketSubject) extra.ticketSubject = String(s.subject ?? "");
          if (!event.payload.replyUrl) extra.replyUrl = `https://presto.app/support/${event.source_id}`;
        } else if (event.source_collection === COLLECTIONS.reports) {
          if (!event.payload.reportId) extra.reportId = event.source_id;
          if (!event.payload.reportUrl) extra.reportUrl = `https://presto.app/support/reports/${event.source_id}`;
          if (!event.payload.resolutionSummary) {
            extra.resolutionSummary = String(s.resolution_summary ?? s.resolutionSummary ?? s.moderator_note ?? "Votre signalement a été traité par notre équipe.");
          }
        } else if (event.source_collection === COLLECTIONS.billingInvoices) {
          Object.assign(extra, buildBillingInvoiceEnrichment(s, event.payload));
        } else if (event.source_collection === COLLECTIONS.subscriptions) {
          Object.assign(extra, buildSubscriptionEnrichment(s, event.payload));
        }
      }
    } catch {
      // best-effort
    }
  }

  // URL tableau de bord universelle
  if (!event.payload.dashboardUrl) {
    extra.dashboardUrl = "https://presto.app/dashboard";
  }

  return {
    ...event,
    payload: {
      ...event.payload,
      ...extra,
    },
  };
}
