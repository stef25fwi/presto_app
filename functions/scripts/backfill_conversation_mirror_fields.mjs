#!/usr/bin/env node

import admin from 'firebase-admin';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    limit: 0,
    projectId: process.env.GCLOUD_PROJECT || '',
  };

  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (arg.startsWith('--limit=')) {
      const value = Number(arg.slice('--limit='.length));
      if (!Number.isNaN(value) && value > 0) opts.limit = Math.floor(value);
      continue;
    }
    if (arg.startsWith('--project=')) {
      opts.projectId = arg.slice('--project='.length).trim();
    }
  }

  return opts;
}

function normalizeMessageText(value) {
  return String(value ?? '')
    .split('\n')
    .map((line) => line.replace(/\s+$/g, ''))
    .join('\n')
    .trim();
}

async function main() {
  const opts = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(opts.projectId ? { projectId: opts.projectId } : {});
  }

  const {
    buildConversationMirrorFields,
    readConversationMirrorData,
  } = require('../lib/modules/messaging/mirror.js');
  const { readConversationParticipants } = require('../lib/modules/messaging/participants.js');
  const { computeConversationStatus } = require('../lib/modules/messaging/state.js');

  const db = admin.firestore();
  const conversations = db.collection('conversations');

  let scanned = 0;
  let updated = 0;
  let lastDoc;
  let batch = db.batch();
  let batchCount = 0;
  const MAX_BATCH = 400;

  while (true) {
    let query = conversations.orderBy(admin.firestore.FieldPath.documentId()).limit(100);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      if (opts.limit > 0 && scanned >= opts.limit) break;
      scanned += 1;
      lastDoc = doc;

      const raw = doc.data() || {};
      const mirror = readConversationMirrorData(raw);
      const participants = readConversationParticipants(raw);
      const participantNames = { ...mirror.participantNames };
      const archivedBy = { ...mirror.archivedBy };
      const blockedBy = { ...mirror.blockedBy };

      let messageCount = mirror.messageCount;
      let lastMessage = mirror.lastMessage;
      let lastSenderId = mirror.lastSenderId;
      let lastSenderName = mirror.lastSenderName;
      let lastMessageAt = mirror.lastMessageAt;

      const needsMessageBackfill =
        messageCount <= 0 ||
        !lastMessageAt ||
        (!lastMessage && messageCount > 0) ||
        !lastSenderId ||
        !lastSenderName;

      if (needsMessageBackfill) {
        const messagesRef = doc.ref.collection('messages');
        const [latestSnap, countSnap] = await Promise.all([
          messagesRef.orderBy('createdAt', 'desc').limit(1).get(),
          messagesRef.count().get(),
        ]);
        const latest = latestSnap.docs[0]?.data() || {};
        messageCount = countSnap.data().count;
        lastMessage = latestSnap.empty ? '' : normalizeMessageText(latest.text ?? latest.body);
        lastSenderId = latestSnap.empty ? '' : String(latest.senderId || latest.sender_id || '').trim();
        lastSenderName = latestSnap.empty ? '' : String(latest.senderName || latest.sender_name || '').trim();
        lastMessageAt = latest.createdAt ?? latest.created_at ?? lastMessageAt;

        if (lastSenderId && lastSenderName && !participantNames[lastSenderId]) {
          participantNames[lastSenderId] = lastSenderName;
        }
      }

      const patch = buildConversationMirrorFields({
        ...mirror,
        participants,
        participantNames,
        archivedBy,
        blockedBy,
        messageCount,
        lastMessage,
        lastSenderId,
        lastSenderName,
        lastMessageAt,
        status: computeConversationStatus(participants, archivedBy, blockedBy),
      });

      if (opts.dryRun) {
        console.log(`[dry-run] conversations/${doc.id} -> mirrored fields refreshed`);
        continue;
      }

      batch.set(doc.ref, patch, { merge: true });
      batchCount += 1;

      if (batchCount >= MAX_BATCH) {
        await batch.commit();
        updated += batchCount;
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (opts.limit > 0 && scanned >= opts.limit) break;
    if (snapshot.size < 100) break;
  }

  if (!opts.dryRun && batchCount > 0) {
    await batch.commit();
    updated += batchCount;
  }

  console.log('--- conversation mirror backfill summary ---');
  console.log(`scanned: ${scanned}`);
  console.log(`updated: ${opts.dryRun ? 0 : updated}`);
  console.log(`mode: ${opts.dryRun ? 'dry-run' : 'apply'}`);
}

main().catch((error) => {
  console.error('[backfill_conversation_mirror_fields] failed:', error);
  process.exitCode = 1;
});