#!/usr/bin/env node
/**
 * Hygiène des destinataires : cohérence entre les contacts bloqués côté Brevo
 * et la collection Firestore `email_suppressions`, puis détection des envois
 * partis malgré une suppression active (boucle d'envoi).
 */
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

function readArg(name, fallback) {
  const direct = process.argv.find((arg) => arg.startsWith(`${name}=`));
  if (direct) return direct.slice(name.length + 1);
  const idx = process.argv.indexOf(name);
  if (idx >= 0 && process.argv[idx + 1] && !process.argv[idx + 1].startsWith("--")) {
    return process.argv[idx + 1];
  }
  return fallback;
}

/** Motifs Brevo qui doivent impérativement exister en suppression Firestore. */
const BLOCKING_REASON_PATTERNS = ["hardbounce", "spam", "invalid", "blocked", "unsubscrib"];

function isBlockingReason(reason) {
  const normalized = String(reason || "").toLowerCase();
  return BLOCKING_REASON_PATTERNS.some((pattern) => normalized.includes(pattern));
}

function toMillis(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return value > 1e12 ? value : value * 1000;
  const parsed = Date.parse(String(value));
  return Number.isNaN(parsed) ? null : parsed;
}

const apiKey = String(process.env.BREVO_API_KEY || "").trim();
if (!apiKey) throw new Error("BREVO_API_KEY is required");

const days = Number(readArg("--days", process.env.BREVO_SUPPRESSION_DAYS || "90"));
if (!Number.isInteger(days) || days < 1 || days > 365) {
  throw new Error("--days doit être un entier entre 1 et 365");
}
const output = readArg("--output", "quality/brevo-suppression-hygiene.json");
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "presto-app-74abe";
const windowStart = Date.now() - days * 24 * 60 * 60 * 1000;

async function fetchBlockedContacts() {
  const contacts = [];
  const limit = 100;
  let offset = 0;

  for (;;) {
    const params = new URLSearchParams({
      startDate: new Date(windowStart).toISOString().slice(0, 10),
      endDate: new Date().toISOString().slice(0, 10),
      limit: String(limit),
      offset: String(offset),
    });
    const response = await fetch(`https://api.brevo.com/v3/smtp/blockedContacts?${params}`, {
      headers: { accept: "application/json", "api-key": apiKey },
    });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Brevo GET /smtp/blockedContacts -> HTTP ${response.status} ${body.slice(0, 300)}`);
    }

    const body = await response.json();
    const page = body?.contacts || [];
    for (const contact of page) {
      contacts.push({
        email: String(contact.email || "").trim().toLowerCase(),
        reason: String(contact.reason?.code || contact.reason?.message || "unknown"),
        blockedAt: toMillis(contact.blockedAt),
      });
    }
    if (page.length < limit) break;
    offset += limit;
    if (offset >= 5000) break;
  }

  return contacts.filter((contact) => contact.email.includes("@"));
}

if (getApps().length === 0) initializeApp({ projectId });
const db = getFirestore();

const blocked = await fetchBlockedContacts();
const blocking = blocked.filter((contact) => isBlockingReason(contact.reason));

const missingSuppressions = [];
const inactiveSuppressions = [];
const suppressedAt = new Map();

for (const contact of blocking) {
  const doc = await db.collection("email_suppressions").doc(contact.email).get();
  const data = doc.data();
  if (!doc.exists || !data) {
    missingSuppressions.push(contact);
    continue;
  }
  if (data.active !== true) {
    inactiveSuppressions.push({ ...contact, reason_firestore: data.reason || null });
    continue;
  }
  suppressedAt.set(contact.email, Number(data.created_at || contact.blockedAt || 0));
}

// Toute suppression active, y compris celles créées hors Brevo, doit bloquer
// les envois suivants : on relit les logs d'envoi de la fenêtre.
const activeSuppressionsSnap = await db
  .collection("email_suppressions")
  .where("active", "==", true)
  .limit(2000)
  .get();
for (const doc of activeSuppressionsSnap.docs) {
  const data = doc.data() || {};
  const email = String(data.email || doc.id).trim().toLowerCase();
  const createdAt = Number(data.created_at || 0);
  const known = suppressedAt.get(email);
  if (known === undefined || createdAt < known) suppressedAt.set(email, createdAt);
}

const sentLogsSnap = await db
  .collection("email_logs")
  .where("status", "==", "sent")
  .where("created_at", ">=", windowStart)
  .limit(2000)
  .get();

const postSuppressionSends = [];
for (const doc of sentLogsSnap.docs) {
  const data = doc.data() || {};
  const email = String(data.recipient_email || "").trim().toLowerCase();
  if (!email) continue;
  const suppressionTime = suppressedAt.get(email);
  if (suppressionTime === undefined) continue;
  const sentAt = Number(data.created_at || 0);
  if (sentAt > suppressionTime) {
    postSuppressionSends.push({
      email,
      template_code: data.template_code || null,
      job_id: data.job_id || null,
      sent_at: sentAt,
      suppressed_at: suppressionTime,
    });
  }
}

const ok = missingSuppressions.length === 0
  && inactiveSuppressions.length === 0
  && postSuppressionSends.length === 0;

const report = {
  generatedAt: new Date().toISOString(),
  windowDays: days,
  blockedContacts: blocked.length,
  blockingContacts: blocking.length,
  activeSuppressions: activeSuppressionsSnap.size,
  sentLogsInspected: sentLogsSnap.size,
  missingSuppressions,
  inactiveSuppressions,
  postSuppressionSends,
  ok,
};

await mkdir(dirname(output), { recursive: true });
await writeFile(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");

console.log(`Contacts bloqués Brevo (${days} j) : ${blocked.length} dont ${blocking.length} bloquants`);
console.log(`Suppressions actives Firestore : ${activeSuppressionsSnap.size}`);
console.log(`Logs d envoi inspectés : ${sentLogsSnap.size}`);
for (const contact of missingSuppressions) {
  console.error(`MANQUE suppression Firestore pour ${contact.email} (${contact.reason})`);
}
for (const contact of inactiveSuppressions) {
  console.error(`SUPPRESSION INACTIVE pour ${contact.email} bloqué chez Brevo (${contact.reason})`);
}
for (const send of postSuppressionSends) {
  console.error(`ENVOI APRÈS SUPPRESSION ${send.email} (${send.template_code || "template inconnu"})`);
}

console.log(`BREVO_SUPPRESSION_HYGIENE_RESULT=${JSON.stringify({
  ok,
  missing: missingSuppressions.length,
  inactive: inactiveSuppressions.length,
  postSuppressionSends: postSuppressionSends.length,
})}`);
console.log(`Report: ${output}`);

if (!ok) process.exit(2);
