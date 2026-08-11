#!/usr/bin/env node

import admin from 'firebase-admin';

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'presto-app-74abe';
const recipient = String(process.env.CANARY_RECIPIENT || 'contact@ilipresto.fr').trim().toLowerCase();
const timeoutMs = Number(process.env.RUNTIME_CANARY_TIMEOUT_MS || 90000);
const pollMs = 2500;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

if (!recipient || !recipient.includes('@')) {
  throw new Error('CANARY_RECIPIENT invalide');
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}
const db = admin.firestore();

const now = Date.now();
const eventId = `evt_brevo_runtime_canary_${now}_${Math.random().toString(16).slice(2, 10)}`;
const ticketNumber = `BREVO-${new Date(now).toISOString().replace(/[-:.TZ]/g, '').slice(0, 14)}`;

await db.collection('email_events').doc(eventId).set({
  event_id: eventId,
  event_name: 'support.ticket.created',
  source_collection: 'brevo_certification_canary',
  source_id: eventId,
  dedupe_key: eventId,
  occurred_at: now,
  payload: {
    recipient_email: recipient,
    firstName: 'Certification',
    ticketNumber,
    ticketSubject: 'Canari technique Brevo production',
    ticketUrl: 'https://ilipresto.fr',
    replyUrl: 'https://ilipresto.fr',
    certificationCanary: true,
  },
  status: 'created',
  certification_canary: true,
  certification_created_at: now,
});

console.log(`Canari runtime créé: ${eventId}`);

const deadline = Date.now() + timeoutMs;
let lastJob = null;
let lastLogs = [];

while (Date.now() < deadline) {
  const [jobsSnap, logsSnap, eventSnap] = await Promise.all([
    db.collection('email_jobs').where('event_id', '==', eventId).limit(5).get(),
    db.collection('email_logs').where('event_id', '==', eventId).limit(20).get(),
    db.collection('email_events').doc(eventId).get(),
  ]);

  lastJob = jobsSnap.docs[0]?.data() || null;
  lastLogs = logsSnap.docs.map((doc) => doc.data() || {});

  const sentLog = lastLogs.find((log) => ['sent', 'delivered'].includes(String(log.status || '')));
  if (sentLog || ['sent'].includes(String(lastJob?.status || ''))) {
    const result = {
      ok: true,
      eventId,
      eventStatus: eventSnap.data()?.status || null,
      jobStatus: lastJob?.status || null,
      provider: sentLog?.provider || null,
      providerMessageId: sentLog?.provider_message_id || lastJob?.provider_message_id || null,
      logStatuses: lastLogs.map((log) => String(log.status || 'unknown')),
    };
    console.log(`BREVO_RUNTIME_CANARY_RESULT=${JSON.stringify(result)}`);
    process.exit(0);
  }

  const failedLog = lastLogs.find((log) => String(log.status || '') === 'failed');
  const terminalJob = ['dead_letter', 'cancelled'].includes(String(lastJob?.status || ''));
  if (failedLog || terminalJob) {
    const result = {
      ok: false,
      eventId,
      eventStatus: eventSnap.data()?.status || null,
      jobStatus: lastJob?.status || null,
      errorCode: failedLog?.error_code || lastJob?.last_error_code || null,
      errorMessage: failedLog?.error_message || lastJob?.last_error_message || null,
      logStatuses: lastLogs.map((log) => String(log.status || 'unknown')),
    };
    console.log(`BREVO_RUNTIME_CANARY_RESULT=${JSON.stringify(result)}`);
    process.exit(2);
  }

  await sleep(pollMs);
}

const timeoutResult = {
  ok: false,
  eventId,
  jobStatus: lastJob?.status || null,
  errorCode: lastJob?.last_error_code || 'runtime_canary_timeout',
  errorMessage: lastJob?.last_error_message || 'Aucun résultat du pipeline email avant expiration.',
  logStatuses: lastLogs.map((log) => String(log.status || 'unknown')),
};
console.log(`BREVO_RUNTIME_CANARY_RESULT=${JSON.stringify(timeoutResult)}`);
process.exit(3);
