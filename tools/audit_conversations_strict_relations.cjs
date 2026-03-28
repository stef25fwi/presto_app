const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'presto-app-74abe';
const PARTICIPANT_QUERY_FIELDS = [
  'participants',
  'participant_ids',
  'participantIds',
  'userIds',
  'memberIds',
];
const PARTICIPANT_MAP_FIELDS = [
  'participantNames',
  'participant_names',
  'unreadCount',
  'unread_count',
  'lastReadAt',
  'last_read_at',
  'archivedBy',
  'blockedBy',
];

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

function normalizeString(value) {
  return String(value ?? '').trim();
}

function parseArgs(argv) {
  const options = {
    limit: 0,
    sampleSize: 10,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg.startsWith('--limit=')) {
      const value = Number(arg.slice('--limit='.length));
      if (!Number.isNaN(value) && value > 0) options.limit = Math.floor(value);
    }
    if (arg.startsWith('--sample=')) {
      const value = Number(arg.slice('--sample='.length));
      if (!Number.isNaN(value) && value > 0) options.sampleSize = Math.floor(value);
    }
  }

  return options;
}

function readArray(data, field) {
  const raw = data[field];
  if (!Array.isArray(raw)) return [];
  return raw.map((value) => normalizeString(value)).filter(Boolean);
}

function readMapKeys(data, field) {
  const raw = data[field];
  if (!raw || typeof raw !== 'object') return [];
  return Object.keys(raw).map((value) => normalizeString(value)).filter(Boolean);
}

function readParticipants(data) {
  const seen = new Set();
  const result = [];

  const append = (value) => {
    const normalized = normalizeString(value);
    if (!normalized || seen.has(normalized)) return;
    seen.add(normalized);
    result.push(normalized);
  };

  for (const field of PARTICIPANT_QUERY_FIELDS) {
    for (const value of readArray(data, field)) append(value);
  }

  for (const field of PARTICIPANT_MAP_FIELDS) {
    for (const key of readMapKeys(data, field)) append(key);
  }

  return result.sort();
}

function readString(data, keys) {
  for (const key of keys) {
    const normalized = normalizeString(data[key]);
    if (normalized) return normalized;
  }
  return '';
}

function readMessageCount(data) {
  const raw = data.messageCount ?? data.message_count;
  if (typeof raw === 'number' && Number.isFinite(raw) && raw >= 0) {
    return Math.floor(raw);
  }
  return readString(data, ['lastMessage', 'last_message']).length > 0 ? 1 : 0;
}

function parseDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function sameSetSubsetOfParticipants(map, participants) {
  const participantSet = new Set(participants.map((value) => normalizeString(value)).filter(Boolean));
  return Object.keys(map || {})
    .map((value) => normalizeString(value))
    .filter(Boolean)
    .every((key) => participantSet.has(key));
}

function normalizeDisplayName(data) {
  return normalizeString(data?.displayName) ||
    normalizeString(data?.display_name) ||
    normalizeString(data?.name) ||
    normalizeString(data?.pseudo) ||
    normalizeString(data?.email);
}

function canonicalConversationId(offerId, participants) {
  return `offer_${offerId.replaceAll('/', '_')}__${participants
    .map((value) => value.replaceAll('/', '_'))
    .sort()
    .join('__')}`;
}

function pushSample(target, limit, entry) {
  if (target.length >= limit) return;
  target.push(entry);
}

async function resolveOfferDoc(offerId) {
  if (!offerId) {
    return { exists: false, source: '', data: null };
  }

  const [offerSnap, listingSnap] = await Promise.all([
    db.collection('offers').doc(offerId).get(),
    db.collection('listings').doc(offerId).get(),
  ]);

  if (offerSnap.exists) {
    return { exists: true, source: 'offers', data: offerSnap.data() || {} };
  }
  if (listingSnap.exists) {
    return { exists: true, source: 'listings', data: listingSnap.data() || {} };
  }

  return { exists: false, source: '', data: null };
}

function readOwnerId(data) {
  return normalizeString(data?.ownerId) ||
    normalizeString(data?.userId) ||
    normalizeString(data?.uid) ||
    normalizeString(data?.advertiserId);
}

async function main() {
  const options = parseArgs(process.argv);
  const summary = {
    scanned: 0,
    participantCountNotTwo: 0,
    missingUserDocs: 0,
    participantNameMismatches: 0,
    missingOfferSourceDoc: 0,
    offerOwnerNotParticipant: 0,
    offerTitleMismatch: 0,
    conversationIdMismatch: 0,
    messageCountMismatch: 0,
    latestMessageMirrorMismatch: 0,
    unreadMapKeyMismatch: 0,
    archivedMapForeignKeyMismatch: 0,
    blockedMapForeignKeyMismatch: 0,
    lastReadMapForeignKeyMismatch: 0,
    informationalSparseMaps: 0,
    samples: {
      participantCountNotTwo: [],
      missingUserDocs: [],
      participantNameMismatches: [],
      missingOfferSourceDoc: [],
      offerOwnerNotParticipant: [],
      offerTitleMismatch: [],
      conversationIdMismatch: [],
      messageCountMismatch: [],
      latestMessageMirrorMismatch: [],
      unreadMapKeyMismatch: [],
      archivedMapForeignKeyMismatch: [],
      blockedMapForeignKeyMismatch: [],
      lastReadMapForeignKeyMismatch: [],
      informationalSparseMaps: [],
    },
  };

  let query = db.collection('conversations').orderBy(admin.firestore.FieldPath.documentId()).limit(100);
  let lastDoc = null;

  while (true) {
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      summary.scanned += 1;
      const data = doc.data() || {};
      const conversationId = doc.id;
      const participants = readParticipants(data);
      const participantNames = data.participantNames || data.participant_names || {};
      const unreadMap = data.unreadCount || data.unread_count || {};
      const archivedMap = data.archivedBy || {};
      const blockedMap = data.blockedBy || {};
      const lastReadMap = data.lastReadAt || data.last_read_at || {};
      const offerId = readString(data, ['offerId', 'offer_id']);
      const offerTitle = readString(data, ['offerTitle', 'offer_title']);

      if (participants.length !== 2) {
        summary.participantCountNotTwo += 1;
        pushSample(summary.samples.participantCountNotTwo, options.sampleSize, {
          id: conversationId,
          participants,
        });
      }

      const userSnaps = await Promise.all(
        participants.map((participantId) => db.collection('users').doc(participantId).get()),
      );
      const missingUsers = participants.filter((participantId, index) => !userSnaps[index].exists);
      if (missingUsers.length > 0) {
        summary.missingUserDocs += 1;
        pushSample(summary.samples.missingUserDocs, options.sampleSize, {
          id: conversationId,
          missingUsers,
        });
      }

      const mismatchedNames = [];
      for (let index = 0; index < participants.length; index += 1) {
        const participantId = participants[index];
        const userData = userSnaps[index].data() || {};
        const expectedName = normalizeDisplayName(userData);
        const mirroredName = normalizeString(participantNames[participantId]);
        if (expectedName && mirroredName && expectedName !== mirroredName) {
          mismatchedNames.push({ participantId, expectedName, mirroredName });
        }
      }
      if (mismatchedNames.length > 0) {
        summary.participantNameMismatches += 1;
        pushSample(summary.samples.participantNameMismatches, options.sampleSize, {
          id: conversationId,
          mismatchedNames,
        });
      }

      const offerDoc = await resolveOfferDoc(offerId);
      if (!offerDoc.exists) {
        summary.missingOfferSourceDoc += 1;
        pushSample(summary.samples.missingOfferSourceDoc, options.sampleSize, {
          id: conversationId,
          offerId,
        });
      } else {
        const sourceTitle = normalizeString(offerDoc.data?.title);
        const ownerId = readOwnerId(offerDoc.data);
        if (ownerId && !participants.includes(ownerId)) {
          summary.offerOwnerNotParticipant += 1;
          pushSample(summary.samples.offerOwnerNotParticipant, options.sampleSize, {
            id: conversationId,
            offerId,
            ownerId,
            participants,
            source: offerDoc.source,
          });
        }
        if (sourceTitle && offerTitle && sourceTitle !== offerTitle) {
          summary.offerTitleMismatch += 1;
          pushSample(summary.samples.offerTitleMismatch, options.sampleSize, {
            id: conversationId,
            offerId,
            mirroredOfferTitle: offerTitle,
            sourceOfferTitle: sourceTitle,
            source: offerDoc.source,
          });
        }
      }

      if (offerId && participants.length > 0) {
        const expectedConversationId = canonicalConversationId(offerId, participants);
        if (expectedConversationId !== conversationId) {
          summary.conversationIdMismatch += 1;
          pushSample(summary.samples.conversationIdMismatch, options.sampleSize, {
            id: conversationId,
            expectedConversationId,
          });
        }
      }

      const messagesRef = doc.ref.collection('messages');
      const [countSnap, latestSnap] = await Promise.all([
        messagesRef.count().get(),
        messagesRef.orderBy('createdAt', 'desc').limit(1).get(),
      ]);
      const realCount = countSnap.data().count;
      const mirroredCount = readMessageCount(data);
      if (realCount !== mirroredCount) {
        summary.messageCountMismatch += 1;
        pushSample(summary.samples.messageCountMismatch, options.sampleSize, {
          id: conversationId,
          mirroredCount,
          realCount,
        });
      }

      const latestData = latestSnap.docs[0]?.data() || null;
      if (latestData) {
        const mirroredLastMessage = readString(data, ['lastMessage', 'last_message']);
        const mirroredLastSenderId = readString(data, ['lastSenderId', 'last_sender_id']);
        const mirroredLastSenderName = readString(data, ['lastSenderName', 'last_sender_name']);
        const mirroredLastMessageAtDate = parseDate(data.lastMessageAt ?? data.last_message_at);
        const mirroredLastMessageAt = mirroredLastMessageAtDate?.toISOString() ?? null;

        const actualLastMessage = normalizeString(latestData.text ?? latestData.body);
        const actualLastSenderId = normalizeString(latestData.senderId ?? latestData.sender_id);
        const actualLastSenderName = normalizeString(latestData.senderName ?? latestData.sender_name);
        const actualLastMessageAtDate = parseDate(latestData.createdAt ?? latestData.created_at);
        const actualLastMessageAt = actualLastMessageAtDate?.toISOString() ?? null;
        const timestampDeltaMs = mirroredLastMessageAtDate && actualLastMessageAtDate
          ? Math.abs(mirroredLastMessageAtDate.getTime() - actualLastMessageAtDate.getTime())
          : Number.POSITIVE_INFINITY;

        if (
          mirroredLastMessage !== actualLastMessage ||
          mirroredLastSenderId !== actualLastSenderId ||
          mirroredLastSenderName !== actualLastSenderName ||
          timestampDeltaMs > 5000
        ) {
          summary.latestMessageMirrorMismatch += 1;
          pushSample(summary.samples.latestMessageMirrorMismatch, options.sampleSize, {
            id: conversationId,
            mirrored: {
              lastMessage: mirroredLastMessage,
              lastSenderId: mirroredLastSenderId,
              lastSenderName: mirroredLastSenderName,
              lastMessageAt: mirroredLastMessageAt,
            },
            actual: {
              lastMessage: actualLastMessage,
              lastSenderId: actualLastSenderId,
              lastSenderName: actualLastSenderName,
              lastMessageAt: actualLastMessageAt,
            },
            timestampDeltaMs,
          });
        }
      }

      const participantKeySet = JSON.stringify([...participants].sort());
      const compareMapKeys = (map) => JSON.stringify(Object.keys(map || {}).map((value) => normalizeString(value)).filter(Boolean).sort());

      if (compareMapKeys(unreadMap) !== participantKeySet) {
        summary.unreadMapKeyMismatch += 1;
        pushSample(summary.samples.unreadMapKeyMismatch, options.sampleSize, {
          id: conversationId,
          participants,
          unreadKeys: Object.keys(unreadMap || {}),
        });
      }
      if (!sameSetSubsetOfParticipants(archivedMap, participants)) {
        summary.archivedMapForeignKeyMismatch += 1;
        pushSample(summary.samples.archivedMapForeignKeyMismatch, options.sampleSize, {
          id: conversationId,
          participants,
          archivedKeys: Object.keys(archivedMap || {}),
        });
      }
      if (!sameSetSubsetOfParticipants(blockedMap, participants)) {
        summary.blockedMapForeignKeyMismatch += 1;
        pushSample(summary.samples.blockedMapForeignKeyMismatch, options.sampleSize, {
          id: conversationId,
          participants,
          blockedKeys: Object.keys(blockedMap || {}),
        });
      }
      if (!sameSetSubsetOfParticipants(lastReadMap, participants)) {
        summary.lastReadMapForeignKeyMismatch += 1;
        pushSample(summary.samples.lastReadMapForeignKeyMismatch, options.sampleSize, {
          id: conversationId,
          participants,
          lastReadKeys: Object.keys(lastReadMap || {}),
        });
      }

      const sparseMapKinds = [];
      if (compareMapKeys(archivedMap) !== participantKeySet) sparseMapKinds.push('archivedBy');
      if (compareMapKeys(blockedMap) !== participantKeySet) sparseMapKinds.push('blockedBy');
      if (compareMapKeys(lastReadMap) !== participantKeySet) sparseMapKinds.push('lastReadAt');
      if (sparseMapKinds.length > 0) {
        summary.informationalSparseMaps += 1;
        pushSample(summary.samples.informationalSparseMaps, options.sampleSize, {
          id: conversationId,
          participants,
          sparseMapKinds,
        });
      }

      if (options.limit > 0 && summary.scanned >= options.limit) break;
      lastDoc = doc;
    }

    if (options.limit > 0 && summary.scanned >= options.limit) break;
    if (snapshot.size < 100) break;
    query = db.collection('conversations')
      .orderBy(admin.firestore.FieldPath.documentId())
      .startAfter(lastDoc)
      .limit(100);
  }

  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error('[audit_conversations_strict_relations] failed:', error);
  process.exitCode = 1;
});