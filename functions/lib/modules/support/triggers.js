"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onSupportTicketReplied = exports.onSupportTicketCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
exports.onSupportTicketCreated = (0, firestore_1.onDocumentCreated)("support_tickets/{ticketId}", async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    const userId = String(data.user_id || "");
    const user = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email)
        return;
    const ticketId = event.params.ticketId;
    const now = Date.now();
    const eventId = `evt_support_ticket_created_${ticketId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "support.ticket.created",
        source_collection: constants_1.COLLECTIONS.supportTickets,
        source_id: ticketId,
        recipient_user_id: userId,
        dedupe_key: (0, hash_1.sha256)(`support.ticket.created:${ticketId}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            ticketId,
            ticketUrl: `https://presto.app/support/${ticketId}`,
        },
        status: "created",
    });
});
exports.onSupportTicketReplied = (0, firestore_1.onDocumentUpdated)("support_tickets/{ticketId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after)
        return;
    if (before.last_reply_from === after.last_reply_from)
        return;
    if (after.last_reply_from !== "support")
        return;
    const userId = String(after.user_id || "");
    const user = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email)
        return;
    const ticketId = event.params.ticketId;
    const now = Date.now();
    const eventId = `evt_support_ticket_replied_${ticketId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "support.ticket.replied",
        source_collection: constants_1.COLLECTIONS.supportTickets,
        source_id: ticketId,
        recipient_user_id: userId,
        dedupe_key: (0, hash_1.sha256)(`support.ticket.replied:${ticketId}:${after.updated_at || now}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            ticketId,
            ticketUrl: `https://presto.app/support/${ticketId}`,
        },
        status: "created",
    });
});
//# sourceMappingURL=triggers.js.map