"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enrichEventPayload = enrichEventPayload;
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
async function enrichEventPayload(event) {
    const extra = { enriched_at: Date.now() };
    // Enrichissement depuis le profil utilisateur destinataire
    const recipientId = event.recipient_user_id;
    if (recipientId) {
        try {
            const userDoc = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(recipientId).get();
            if (userDoc.exists) {
                const u = userDoc.data() ?? {};
                if (!event.payload.recipient_email)
                    extra.recipient_email = String(u.email ?? "");
                if (!event.payload.firstName)
                    extra.firstName = String(u.display_name ?? u.displayName ?? "").split(" ")[0] ?? "";
                if (!event.payload.city)
                    extra.city = String(u.city ?? "");
            }
        }
        catch {
            // best-effort
        }
    }
    // Enrichissement depuis le document source (annonce, conversation, ticket…)
    if (event.source_collection && event.source_id) {
        try {
            const sourceDoc = await firestore_1.db.collection(event.source_collection).doc(event.source_id).get();
            if (sourceDoc.exists) {
                const s = sourceDoc.data() ?? {};
                if (event.source_collection === constants_1.COLLECTIONS.listings) {
                    if (!event.payload.listingTitle)
                        extra.listingTitle = String(s.title ?? "");
                    if (!event.payload.listingUrl)
                        extra.listingUrl = `https://presto.app/listings/${event.source_id}`;
                    if (!event.payload.city)
                        extra.city = String(s.city ?? extra.city ?? "");
                }
                else if (event.source_collection === constants_1.COLLECTIONS.conversations) {
                    if (!event.payload.conversationUrl)
                        extra.conversationUrl = `https://presto.app/messages/${event.source_id}`;
                }
                else if (event.source_collection === constants_1.COLLECTIONS.supportTickets) {
                    if (!event.payload.ticketNumber)
                        extra.ticketNumber = String(s.ticket_number ?? event.source_id);
                    if (!event.payload.ticketSubject)
                        extra.ticketSubject = String(s.subject ?? "");
                }
            }
        }
        catch {
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
//# sourceMappingURL=enrich.js.map