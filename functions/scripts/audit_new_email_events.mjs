#!/usr/bin/env node

import admin from 'firebase-admin';

const DEFAULT_EVENT_NAMES = [
  'user.otp.requested',
  'profile.verified',
  'user.account.deletion.requested',
  'user.account.deleted',
  'billing.subscription.renewed',
  'billing.subscription.expired',
  'listing.first_not_published.reminder',
  'profile.incomplete.reminder',
  'growth.reactivation.30_days',
  'growth.nearby_new_listings',
  'growth.referral_invite',
];

function parseArgs(argv) {
  const opts = {
    projectId: process.env.GCLOUD_PROJECT || '',
    hours: 72,
    limit: 400,
    eventNames: [],
    sampleSize: 3,
    json: false,
    help: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg) continue;

    if (arg === '--help' || arg === '-h') {
      opts.help = true;
      continue;
    }
    if (arg === '--json') {
      opts.json = true;
      continue;
    }
    if (arg.startsWith('--project=')) {
      opts.projectId = arg.slice('--project='.length).trim();
      continue;
    }
    if (arg.startsWith('--hours=')) {
      const value = Number(arg.slice('--hours='.length));
      if (Number.isFinite(value) && value > 0) opts.hours = value;
      continue;
    }
    if (arg.startsWith('--limit=')) {
      const value = Number(arg.slice('--limit='.length));
      if (Number.isFinite(value) && value > 0) opts.limit = Math.floor(value);
      continue;
    }
    if (arg.startsWith('--sample=')) {
      const value = Number(arg.slice('--sample='.length));
      if (Number.isFinite(value) && value >= 0) opts.sampleSize = Math.floor(value);
      continue;
    }
    if (arg.startsWith('--event=')) {
      const value = arg.slice('--event='.length).trim();
      if (value) opts.eventNames.push(value);
    }
  }

  return opts;
}

function usage() {
  console.log('Usage: node scripts/audit_new_email_events.mjs [options]');
  console.log('');
  console.log('Options:');
  console.log('  --project=<firebase_project_id>   Firebase project id');
  console.log('  --hours=<n>                       Audit window in hours, default 72');
  console.log('  --limit=<n>                       Recent email_events docs to scan, default 400');
  console.log('  --sample=<n>                      Sample docs per event, default 3');
  console.log('  --event=<event_name>              Restrict to one event name, repeatable');
  console.log('  --json                            Output JSON instead of text');
  console.log('  --help                            Show this help');
}

function chunk(values, size) {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function countBy(items, keySelector) {
  const counts = {};
  for (const item of items) {
    const key = keySelector(item);
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}

function readNumber(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function summarizeAge(now, occurredAt) {
  if (!occurredAt) return null;
  const ageMs = Math.max(0, now - occurredAt);
  return Math.round(ageMs / 60000);
}

async function main() {
  const opts = parseArgs(process.argv);
  if (opts.help) {
    usage();
    return;
  }

  const targetEventNames = new Set(opts.eventNames.length > 0 ? opts.eventNames : DEFAULT_EVENT_NAMES);
  const cutoffMs = Date.now() - opts.hours * 60 * 60 * 1000;

  if (!admin.apps.length) {
    admin.initializeApp(opts.projectId ? { projectId: opts.projectId } : {});
  }

  const db = admin.firestore();
  const recentEventsSnap = await db
    .collection('email_events')
    .orderBy('occurred_at', 'desc')
    .limit(opts.limit)
    .get();

  const matchedEvents = recentEventsSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
    .filter((doc) => targetEventNames.has(String(doc.event_name || '')))
    .filter((doc) => readNumber(doc.occurred_at) >= cutoffMs);

  const eventIds = matchedEvents.map((doc) => doc.event_id || doc.id).filter(Boolean);
  const jobs = [];
  const logs = [];

  for (const ids of chunk(eventIds, 10)) {
    const [jobsSnap, logsSnap] = await Promise.all([
      db.collection('email_jobs').where('event_id', 'in', ids).get(),
      db.collection('email_logs').where('event_id', 'in', ids).get(),
    ]);

    jobs.push(...jobsSnap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) })));
    logs.push(...logsSnap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) })));
  }

  const jobsByEventId = new Map();
  for (const job of jobs) {
    const eventId = String(job.event_id || '');
    if (!eventId) continue;
    if (!jobsByEventId.has(eventId)) jobsByEventId.set(eventId, []);
    jobsByEventId.get(eventId).push(job);
  }

  const logsByEventId = new Map();
  for (const log of logs) {
    const eventId = String(log.event_id || '');
    if (!eventId) continue;
    if (!logsByEventId.has(eventId)) logsByEventId.set(eventId, []);
    logsByEventId.get(eventId).push(log);
  }

  const now = Date.now();
  const summary = {};
  for (const eventName of targetEventNames) {
    const docs = matchedEvents.filter((doc) => String(doc.event_name || '') === eventName);
    const relatedJobs = docs.flatMap((doc) => jobsByEventId.get(String(doc.event_id || doc.id)) || []);
    const relatedLogs = docs.flatMap((doc) => logsByEventId.get(String(doc.event_id || doc.id)) || []);
    const stuckEvents = docs.filter((doc) => {
      const eventId = String(doc.event_id || doc.id);
      const ageMinutes = summarizeAge(now, readNumber(doc.occurred_at)) || 0;
      const hasJobs = (jobsByEventId.get(eventId) || []).length > 0;
      return !hasJobs && String(doc.status || '') === 'created' && ageMinutes >= 15;
    });

    summary[eventName] = {
      eventsCount: docs.length,
      eventStatuses: countBy(docs, (doc) => String(doc.status || 'unknown')),
      jobsCount: relatedJobs.length,
      jobStatuses: countBy(relatedJobs, (job) => String(job.status || 'unknown')),
      logsCount: relatedLogs.length,
      logStatuses: countBy(relatedLogs, (log) => String(log.status || 'unknown')),
      stuckCreatedWithoutJobs: stuckEvents.length,
      samples: docs.slice(0, opts.sampleSize).map((doc) => ({
        eventId: String(doc.event_id || doc.id),
        status: String(doc.status || 'unknown'),
        recipient: String(doc.payload?.recipient_email || ''),
        occurredAt: readNumber(doc.occurred_at),
      })),
    };
  }

  const output = {
    projectId: opts.projectId || process.env.GCLOUD_PROJECT || null,
    cutoffMs,
    scannedRecentEmailEvents: recentEventsSnap.size,
    matchedEvents: matchedEvents.length,
    targetEventNames: [...targetEventNames],
    summary,
  };

  if (opts.json) {
    console.log(JSON.stringify(output, null, 2));
    return;
  }

  console.log(`Email post-deploy audit over the last ${opts.hours}h`);
  console.log(`Scanned recent email_events: ${recentEventsSnap.size}`);
  console.log(`Matched target events: ${matchedEvents.length}`);
  console.log('');

  for (const eventName of [...targetEventNames]) {
    const item = summary[eventName];
    console.log(`- ${eventName}`);
    console.log(`  events=${item.eventsCount} jobs=${item.jobsCount} logs=${item.logsCount} stuck_created_without_jobs=${item.stuckCreatedWithoutJobs}`);
    console.log(`  event_statuses=${JSON.stringify(item.eventStatuses)}`);
    console.log(`  job_statuses=${JSON.stringify(item.jobStatuses)}`);
    console.log(`  log_statuses=${JSON.stringify(item.logStatuses)}`);
    if (item.samples.length > 0) {
      for (const sample of item.samples) {
        console.log(`  sample eventId=${sample.eventId} status=${sample.status} recipient=${sample.recipient} occurredAt=${sample.occurredAt}`);
      }
    }
    console.log('');
  }
}

main().catch((error) => {
  console.error('Email audit failed:', error);
  process.exit(1);
});