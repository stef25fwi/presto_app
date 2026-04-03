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

function normalizeString(value) {
  return String(value ?? '').trim();
}

function readOwnerId(data) {
  return normalizeString(data?.ownerId)
    || normalizeString(data?.userId)
    || normalizeString(data?.uid)
    || normalizeString(data?.advertiserId);
}

function readUserDisplayName(data) {
  return normalizeString(data?.displayName)
    || normalizeString(data?.display_name)
    || normalizeString(data?.name)
    || normalizeString(data?.pseudo)
    || normalizeString(data?.email);
}

function pickOtherUserName(participants, participantNames, ownerId) {
  if (ownerId && participantNames[ownerId]) {
    return participantNames[ownerId];
  }

  for (const participantId of participants) {
    const participantName = normalizeString(participantNames[participantId]);
    if (participantName) return participantName;
  }

  return '';
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
  const {
    mergeUniqueParticipantIds,
    normalizeParticipantBooleanMap,
    normalizeParticipantNumberMap,
    normalizeParticipantUnknownMap,
    parseCanonicalConversationId,
  } = require('../lib/modules/messaging/repair.js');

  const db = admin.firestore();
  const conversations = db.collection('conversations');
  const userCache = new Map();
  const offerCache = new Map();

  let scanned = 0;
  let updated = 0;
  let lastDoc;
  let batch = db.batch();
  let batchCount = 0;
  const MAX_BATCH = 400;
  const summary = {
    participantsRecovered: 0,
    participantNamesRecovered: 0,
    offerMetadataRecovered: 0,
    mapEntriesNormalized: 0,
    messageMirrorRecovered: 0,
  };

  async function loadOfferLikeData(offerId) {
    const normalizedOfferId = normalizeString(offerId);
    if (!normalizedOfferId) return null;
    if (offerCache.has(normalizedOfferId)) {
      return offerCache.get(normalizedOfferId);
    }

    const [offerSnap, listingSnap] = await Promise.all([
      db.collection('offers').doc(normalizedOfferId).get(),
      db.collection('listings').doc(normalizedOfferId).get(),
    ]);

    const result = offerSnap.exists
      ? (offerSnap.data() || {})
      : listingSnap.exists
        ? (listingSnap.data() || {})
        : null;
    offerCache.set(normalizedOfferId, result);
    return result;
  }

  async function loadUserProfile(userId) {
    const normalizedUserId = normalizeString(userId);
    if (!normalizedUserId) return null;
    if (userCache.has(normalizedUserId)) {
      return userCache.get(normalizedUserId);
    }

    const userSnap = await db.collection('users').doc(normalizedUserId).get();
    const result = userSnap.exists ? (userSnap.data() || {}) : null;
    userCache.set(normalizedUserId, result);
    return result;
  }

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
      const parsedConversationId = parseCanonicalConversationId(doc.id);
      let participants = mergeUniqueParticipantIds(
        readConversationParticipants(raw),
        parsedConversationId.participantIds,
      );
      const participantNames = { ...mirror.participantNames };
      let offerId = normalizeString(mirror.offerId) || normalizeString(parsedConversationId.offerId);
      let offerTitle = normalizeString(mirror.offerTitle);
      let otherUserName = normalizeString(mirror.otherUserName);

      let messageCount = mirror.messageCount;
      let lastMessage = mirror.lastMessage;
      let lastSenderId = mirror.lastSenderId;
      let lastSenderName = mirror.lastSenderName;
      let lastMessageAt = mirror.lastMessageAt;
      let recentMessages = [];

      const needsMessageBackfill =
        messageCount <= 0 ||
        !lastMessageAt ||
        (!lastMessage && messageCount > 0) ||
        !lastSenderId ||
        !lastSenderName;

      const needsParticipantRecovery = participants.length < 2;

      if (needsMessageBackfill || needsParticipantRecovery) {
        const messagesRef = doc.ref.collection('messages');
        const [latestSnap, countSnap, recentMessagesSnap] = await Promise.all([
          messagesRef.orderBy('createdAt', 'desc').limit(1).get(),
          messagesRef.count().get(),
          messagesRef.orderBy('createdAt', 'desc').limit(20).get(),
        ]);
        recentMessages = recentMessagesSnap.docs.map((messageDoc) => messageDoc.data() || {});
        const latest = latestSnap.docs[0]?.data() || {};
        messageCount = countSnap.data().count;
        lastMessage = latestSnap.empty ? '' : normalizeMessageText(latest.text ?? latest.body);
        lastSenderId = latestSnap.empty ? '' : String(latest.senderId || latest.sender_id || '').trim();
        lastSenderName = latestSnap.empty ? '' : String(latest.senderName || latest.sender_name || '').trim();
        lastMessageAt = latest.createdAt ?? latest.created_at ?? lastMessageAt;

        const messageParticipantIds = recentMessages
          .map((message) => normalizeString(message.senderId || message.sender_id))
          .filter(Boolean);
        const recoveredParticipants = mergeUniqueParticipantIds(participants, messageParticipantIds);
        if (recoveredParticipants.length > participants.length) {
          summary.participantsRecovered += 1;
          participants = recoveredParticipants;
        }

        if (lastSenderId && lastSenderName && !participantNames[lastSenderId]) {
          participantNames[lastSenderId] = lastSenderName;
          summary.participantNamesRecovered += 1;
        }

        for (const message of recentMessages) {
          const senderId = normalizeString(message.senderId || message.sender_id);
          const senderName = normalizeString(message.senderName || message.sender_name);
          if (!senderId || !senderName || participantNames[senderId]) continue;
          participantNames[senderId] = senderName;
          summary.participantNamesRecovered += 1;
        }

        summary.messageMirrorRecovered += 1;
      }

      const offerData = await loadOfferLikeData(offerId);
      const offerOwnerId = readOwnerId(offerData || {});
      if (offerOwnerId) {
        const recoveredParticipants = mergeUniqueParticipantIds(participants, [offerOwnerId]);
        if (recoveredParticipants.length > participants.length) {
          summary.participantsRecovered += 1;
          participants = recoveredParticipants;
        }
      }

      const sourceOfferTitle = normalizeString(offerData?.title);
      if (!offerTitle && sourceOfferTitle) {
        offerTitle = sourceOfferTitle;
        summary.offerMetadataRecovered += 1;
      }
      if (!offerId && parsedConversationId.offerId) {
        offerId = normalizeString(parsedConversationId.offerId);
        summary.offerMetadataRecovered += 1;
      }

      for (const participantId of participants) {
        if (participantNames[participantId]) continue;
        const userData = await loadUserProfile(participantId);
        const displayName = readUserDisplayName(userData || {});
        if (!displayName) continue;
        participantNames[participantId] = displayName;
        summary.participantNamesRecovered += 1;
      }

      if (!lastSenderName && lastSenderId && participantNames[lastSenderId]) {
        lastSenderName = participantNames[lastSenderId];
        summary.participantNamesRecovered += 1;
      }

      if (!otherUserName) {
        otherUserName = pickOtherUserName(participants, participantNames, offerOwnerId);
        if (otherUserName) {
          summary.offerMetadataRecovered += 1;
        }
      }

      const archivedBy = normalizeParticipantBooleanMap(participants, mirror.archivedBy);
      const blockedBy = normalizeParticipantBooleanMap(participants, mirror.blockedBy);
      const unreadCount = normalizeParticipantNumberMap(participants, mirror.unreadCount);
      const lastReadAt = normalizeParticipantUnknownMap(participants, mirror.lastReadAt);
      if (participants.length > 0) {
        summary.mapEntriesNormalized += 1;
      }

      const patch = buildConversationMirrorFields({
        ...mirror,
        participants,
        participantNames,
        otherUserName,
        offerId,
        offerTitle,
        archivedBy,
        blockedBy,
        unreadCount,
        lastReadAt,
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
  console.log(`participantsRecovered: ${summary.participantsRecovered}`);
  console.log(`participantNamesRecovered: ${summary.participantNamesRecovered}`);
  console.log(`offerMetadataRecovered: ${summary.offerMetadataRecovered}`);
  console.log(`mapEntriesNormalized: ${summary.mapEntriesNormalized}`);
  console.log(`messageMirrorRecovered: ${summary.messageMirrorRecovered}`);
}

main().catch((error) => {
  console.error('[backfill_conversation_mirror_fields] failed:', error);
  process.exitCode = 1;
});