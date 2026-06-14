import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

export const onSupportTicketCreated = onDocumentCreated("support_tickets/{ticketId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;
  const userId = String(data.user_id || "");
  const user = await db.collection(COLLECTIONS.users).doc(userId).get();
  const email = String(user.data()?.email || "").trim();
  if (!email) return;

  const ticketId = event.params.ticketId;
  const now = Date.now();
  const eventId = `evt_support_ticket_created_${ticketId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "support.ticket.created",
    source_collection: COLLECTIONS.supportTickets,
    source_id: ticketId,
    recipient_user_id: userId,
    dedupe_key: sha256(`support.ticket.created:${ticketId}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      ticketId,
      ticketUrl: `https://ilipresto.fr/support/${ticketId}`,
      replyUrl: `https://ilipresto.fr/support/${ticketId}`,
    },
    status: "created",
  });
});

export const onSupportTicketReplied = onDocumentUpdated("support_tickets/{ticketId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  if (before.last_reply_from === after.last_reply_from) return;
  if (after.last_reply_from !== "support") return;

  const userId = String(after.user_id || "");
  const user = await db.collection(COLLECTIONS.users).doc(userId).get();
  const email = String(user.data()?.email || "").trim();
  if (!email) return;

  const ticketId = event.params.ticketId;
  const now = Date.now();
  const eventId = `evt_support_ticket_replied_${ticketId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "support.ticket.replied",
    source_collection: COLLECTIONS.supportTickets,
    source_id: ticketId,
    recipient_user_id: userId,
    dedupe_key: sha256(`support.ticket.replied:${ticketId}:${after.updated_at || now}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      ticketId,
      ticketUrl: `https://ilipresto.fr/support/${ticketId}`,
      replyUrl: `https://ilipresto.fr/support/${ticketId}`,
    },
    status: "created",
  });
});
