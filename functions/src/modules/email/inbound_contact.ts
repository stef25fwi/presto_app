import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { sha256 } from "../../utils/hash";
import { extractRolesFromAuthToken, requireAnyRole } from "../marketplace/services/roles";
import { createEmailProvider } from "./providers/provider_factory";
import { normalizeHeaders } from "./webhooks/signature";

const INBOUND_COLLECTION = "adminInboundEmails";
const PUBLIC_MAILBOX = "contact@ilipresto.fr";
const DEFAULT_INBOUND_ALIAS = "contact@inbound.ilipresto.fr";
const MAX_WEBHOOK_PAYLOAD_BYTES = 512 * 1024;
const MAX_BODY_CHARS = 20_000;
const MAX_PREVIEW_CHARS = 280;
const MAX_ATTACHMENTS = 12;

interface Mailbox {
  address: string;
  name: string;
}

function cleanString(value: unknown, maxLength = 2_000): string {
  if (typeof value !== "string") return "";
  return value.replace(/\u0000/g, "").trim().slice(0, maxLength);
}

function normalizeEmail(value: unknown): string {
  return cleanString(value, 320).toLowerCase();
}

function mailboxFrom(value: unknown): Mailbox {
  if (typeof value === "string") {
    return { address: normalizeEmail(value), name: "" };
  }
  if (!value || typeof value !== "object") {
    return { address: "", name: "" };
  }
  const raw = value as Record<string, unknown>;
  return {
    address: normalizeEmail(raw.Address ?? raw.address ?? raw.Email ?? raw.email),
    name: cleanString(raw.Name ?? raw.name, 240),
  };
}

function mailboxList(value: unknown): Mailbox[] {
  if (!Array.isArray(value)) return [];
  return value.map(mailboxFrom).filter((item) => item.address.length > 0);
}

function recipientAddresses(item: Record<string, unknown>): string[] {
  const values = [
    ...mailboxList(item.To ?? item.to),
    ...mailboxList(item.Recipients ?? item.recipients),
    ...mailboxList(item.Cc ?? item.cc),
  ];
  return Array.from(new Set(values.map((mailbox) => mailbox.address).filter(Boolean)));
}

function resolvesToContactMailbox(item: Record<string, unknown>): boolean {
  const alias = normalizeEmail(process.env.EMAIL_INBOUND_CONTACT_ALIAS || DEFAULT_INBOUND_ALIAS);
  const recipients = recipientAddresses(item);
  return recipients.includes(PUBLIC_MAILBOX) || recipients.includes(alias);
}

function parseReceivedAt(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value > 10_000_000_000 ? Math.trunc(value) : Math.trunc(value * 1000);
  }
  const text = cleanString(value, 160);
  if (!text) return Date.now();
  const parsed = Date.parse(text);
  return Number.isNaN(parsed) ? Date.now() : parsed;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function attachmentMetadata(value: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(value)) return [];
  return value.slice(0, MAX_ATTACHMENTS).map((entry) => {
    const item = asRecord(entry);
    const rawLength = Number(item.ContentLength ?? item.contentLength ?? 0);
    return {
      name: cleanString(item.Name ?? item.name, 260),
      content_type: cleanString(item.ContentType ?? item.contentType, 160),
      content_length: Number.isFinite(rawLength) && rawLength > 0 ? Math.trunc(rawLength) : 0,
    };
  });
}

function extractSpamScore(item: Record<string, unknown>): number | null {
  const direct = Number(item.SpamScore ?? item.spamScore);
  if (Number.isFinite(direct)) return direct;
  const spam = asRecord(item.Spam ?? item.spam);
  const nested = Number(spam.Score ?? spam.score);
  return Number.isFinite(nested) ? nested : null;
}

function extractItems(payload: unknown): Record<string, unknown>[] {
  if (Array.isArray(payload)) {
    return payload.map(asRecord).filter((item) => Object.keys(item).length > 0);
  }
  const record = asRecord(payload);
  const items = record.items;
  if (Array.isArray(items)) {
    return items.map(asRecord).filter((item) => Object.keys(item).length > 0);
  }
  return Object.keys(record).length > 0 ? [record] : [];
}

function requireAdmin(request: {
  auth?: { uid?: string; token?: Record<string, unknown> } | null;
}): string {
  const uid = cleanString(request.auth?.uid, 160);
  if (!uid) throw new HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
  const roles = extractRolesFromAuthToken(request.auth?.token || {});
  requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");
  return uid;
}

function serializeMail(id: string, data: Record<string, unknown>): Record<string, unknown> {
  const attachments = Array.isArray(data.attachments) ? data.attachments : [];
  return {
    id,
    senderName: cleanString(data.sender_name, 240),
    senderEmail: normalizeEmail(data.sender_email),
    subject: cleanString(data.subject, 500),
    preview: cleanString(data.preview, MAX_PREVIEW_CHARS),
    body: cleanString(data.body_markdown, MAX_BODY_CHARS),
    receivedAt: Number(data.received_at || 0),
    isRead: data.is_read === true,
    attachmentCount: attachments.length,
    spamScore: typeof data.spam_score === "number" ? data.spam_score : null,
  };
}

export const handleInboundContactEmailWebhook = onRequest(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.set("Allow", "POST");
      res.status(405).json({ ok: false, error: "method not allowed" });
      return;
    }

    const rawBody = typeof req.rawBody === "string"
      ? req.rawBody
      : req.rawBody?.toString("utf8") || "";
    const payloadBytes = Buffer.byteLength(rawBody, "utf8");
    if (payloadBytes > MAX_WEBHOOK_PAYLOAD_BYTES) {
      logger.warn("inbound_contact_email_payload_too_large", { payloadBytes });
      res.status(413).json({ ok: false, error: "payload too large" });
      return;
    }

    const provider = createEmailProvider();
    const headers = normalizeHeaders(req.headers);
    if (!provider.verifyWebhookSignature(headers, rawBody)) {
      logger.warn("inbound_contact_email_auth_rejected", { provider: provider.name(), payloadBytes });
      res.status(401).json({ ok: false, error: "invalid webhook authentication" });
      return;
    }

    const items = extractItems(req.body);
    let accepted = 0;
    let ignored = 0;

    for (const item of items) {
      if (!resolvesToContactMailbox(item)) {
        ignored += 1;
        continue;
      }

      const sender = mailboxFrom(item.From ?? item.from);
      const replyTo = mailboxFrom(item.ReplyTo ?? item.replyTo);
      const subject = cleanString(item.Subject ?? item.subject, 500);
      const body = cleanString(
        item.ExtractedMarkdownMessage
          ?? item.extractedMarkdownMessage
          ?? item.RawTextBody
          ?? item.rawTextBody,
        MAX_BODY_CHARS,
      );
      const preview = body.replace(/\s+/g, " ").trim().slice(0, MAX_PREVIEW_CHARS);
      const messageId = cleanString(item.MessageId ?? item.messageId, 1_000);
      const uuidValue = item.Uuid ?? item.uuid;
      const firstUuid = Array.isArray(uuidValue)
        ? cleanString(uuidValue[0], 500)
        : cleanString(uuidValue, 500);
      const stableKey = messageId || firstUuid || `${sender.address}:${subject}:${String(item.SentAtDate ?? "")}`;
      const docId = `inbound_${sha256(`${provider.name()}:${stableKey}`).slice(0, 40)}`;
      const ref = db.collection(INBOUND_COLLECTION).doc(docId);
      const receivedAt = parseReceivedAt(item.SentAtDate ?? item.sentAtDate ?? item.receivedAt);
      const attachments = attachmentMetadata(item.Attachments ?? item.attachments);
      const spamScore = extractSpamScore(item);

      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(ref);
        const previous = existing.data() || {};
        const isRead = previous.is_read === true;
        transaction.set(ref, {
          provider: provider.name(),
          mailbox: PUBLIC_MAILBOX,
          provider_uuid: firstUuid || null,
          message_id: messageId || null,
          in_reply_to: cleanString(item.InReplyTo ?? item.inReplyTo, 1_000) || null,
          sender_name: sender.name,
          sender_email: sender.address,
          reply_to_email: replyTo.address || sender.address,
          subject,
          preview,
          body_markdown: body,
          received_at: receivedAt,
          webhook_received_at: Date.now(),
          recipient_addresses: recipientAddresses(item),
          attachments,
          spam_score: spamScore,
          is_read: isRead,
          read_at: isRead ? previous.read_at ?? null : null,
          updated_at: Date.now(),
          created_at: previous.created_at ?? Date.now(),
        }, { merge: true });
      });
      accepted += 1;
    }

    logger.info("inbound_contact_email_processed", {
      provider: provider.name(),
      accepted,
      ignored,
      payloadBytes,
    });
    res.status(200).json({ ok: true, accepted, ignored });
  },
);

export const adminGetInboundMailboxSummary = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    requireAdmin(request);
    const collection = db.collection(INBOUND_COLLECTION);
    const [unreadSnapshot, latestSnapshot] = await Promise.all([
      collection.where("is_read", "==", false).count().get(),
      collection.orderBy("received_at", "desc").limit(3).get(),
    ]);
    return {
      mailbox: PUBLIC_MAILBOX,
      unreadCount: unreadSnapshot.data().count,
      latest: latestSnapshot.docs.map((doc) => serializeMail(doc.id, doc.data())),
    };
  },
);

export const adminListInboundEmails = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 20,
    memory: "256MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    requireAdmin(request);
    const requestedLimit = Number(asRecord(request.data).limit ?? 30);
    const limit = Math.max(1, Math.min(50, Number.isFinite(requestedLimit) ? Math.trunc(requestedLimit) : 30));
    const snapshot = await db
      .collection(INBOUND_COLLECTION)
      .orderBy("received_at", "desc")
      .limit(limit)
      .get();
    return {
      mailbox: PUBLIC_MAILBOX,
      items: snapshot.docs.map((doc) => serializeMail(doc.id, doc.data())),
    };
  },
);

export const adminMarkInboundEmailRead = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = requireAdmin(request);
    const data = asRecord(request.data);
    const emailId = cleanString(data.emailId, 180);
    if (!/^inbound_[a-f0-9]{40}$/i.test(emailId)) {
      throw new HttpsError("invalid-argument", "INVALID_EMAIL_ID");
    }
    const isRead = data.isRead !== false;
    const ref = db.collection(INBOUND_COLLECTION).doc(emailId);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "EMAIL_NOT_FOUND");
    }
    await ref.set({
      is_read: isRead,
      read_at: isRead ? Date.now() : null,
      read_by: isRead ? uid : null,
      updated_at: Date.now(),
    }, { merge: true });
    return { ok: true, emailId, isRead };
  },
);
