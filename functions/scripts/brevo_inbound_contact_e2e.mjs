#!/usr/bin/env node
import crypto from 'node:crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const apiKey = process.env.BREVO_API_KEY || '';
const projectId = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || 'presto-app-74abe';
const recipient = process.env.INBOUND_SOURCE_ADDRESS || 'contact@ilipresto.fr';
const sender = process.env.INBOUND_TEST_SENDER || 'noreply@ilipresto.fr';
const timeoutMs = Number(process.env.INBOUND_E2E_TIMEOUT_MS || 180000);
const pollMs = Number(process.env.INBOUND_E2E_POLL_MS || 5000);

if (!apiKey) {
  console.error('BREVO_API_KEY manquante.');
  process.exit(2);
}

const token = crypto.randomBytes(6).toString('hex');
const subject = `[ilipresto inbound e2e ${token}]`;
const marker = `ilipresto-inbound-e2e-${token}`;

const sendResponse = await fetch('https://api.brevo.com/v3/smtp/email', {
  method: 'POST',
  headers: {
    accept: 'application/json',
    'api-key': apiKey,
    'content-type': 'application/json',
  },
  body: JSON.stringify({
    sender: { email: sender, name: 'iliprestō production check' },
    to: [{ email: recipient }],
    subject,
    textContent: `${marker}\nTest automatique du routage contact@ilipresto.fr vers Brevo inbound.`,
    headers: { 'X-Ilipresto-Inbound-E2E': token },
  }),
});

if (!sendResponse.ok) {
  const body = await sendResponse.text();
  console.error(`Brevo SMTP API a refusé le mail E2E (${sendResponse.status}): ${body.slice(0, 1000)}`);
  process.exit(3);
}

const accepted = await sendResponse.json().catch(() => ({}));
console.log(`Mail E2E accepté par Brevo: ${accepted.messageId || 'messageId indisponible'}`);
console.log(`Sujet de corrélation: ${subject}`);

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const deadline = Date.now() + timeoutMs;
let match = null;

while (Date.now() < deadline) {
  const snapshot = await db
    .collection('adminInboundEmails')
    .where('subject', '==', subject)
    .limit(1)
    .get();

  if (!snapshot.empty) {
    match = snapshot.docs[0];
    break;
  }

  await new Promise((resolve) => setTimeout(resolve, pollMs));
}

if (!match) {
  console.error('Aucun mail E2E reçu dans adminInboundEmails avant expiration du délai.');
  console.error('Vérifier le transfert/copie LWS contact@ilipresto.fr -> contact@inbound.ilipresto.fr, le domaine inbound Brevo et le webhook inbound.');
  process.exit(4);
}

const data = match.data();
const mailbox = String(data.mailbox || '');
const toAddresses = Array.isArray(data.to_addresses) ? data.to_addresses : [];

console.log(`Mail inbound reçu dans Firestore: ${match.id}`);
console.log(`Mailbox: ${mailbox || 'non renseignée'}`);
console.log(`Destinataires normalisés: ${toAddresses.join(', ') || 'non renseignés'}`);

await match.ref.delete();
console.log('Mail de certification supprimé de la boîte admin après validation pour éviter de polluer le widget.');
console.log(`BREVO_INBOUND_E2E_RESULT=${JSON.stringify({
  ok: true,
  subject,
  documentId: match.id,
  mailbox,
  messageId: accepted.messageId || null,
})}`);
