const admin = require('../functions/node_modules/firebase-admin');
const fs = require('fs');
const path = require('path');

function resolveDefaultProjectId() {
  const envProjectId = process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    '';
  if (envProjectId.trim()) return envProjectId.trim();

  try {
    const firebaseRcPath = path.resolve(__dirname, '..', '.firebaserc');
    const firebaseRc = JSON.parse(fs.readFileSync(firebaseRcPath, 'utf8'));
    return String(firebaseRc?.projects?.default || '').trim();
  } catch (_) {
    return 'presto-app-74abe';
  }
}

let PROJECT_ID = resolveDefaultProjectId();
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

function normalizeString(value) {
  return String(value ?? '').trim();
}

function parseArgs(argv) {
  const options = {
    limit: 0,
    sampleSize: 15,
    projectId: PROJECT_ID,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg.startsWith('--project=')) {
      options.projectId = arg.slice('--project='.length).trim() || options.projectId;
    }
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

const parsedOptions = parseArgs(process.argv);
PROJECT_ID = parsedOptions.projectId;

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

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
  const result = [];
  const seen = new Set();

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

function hasRenderableContent(data) {
  return readMessageCount(data) > 0 ||
    readString(data, ['lastMessage', 'last_message']).length > 0 ||
    parseDate(data.lastMessageAt ?? data.last_message_at) != null ||
    readString(data, ['offerTitle', 'offer_title']).length > 0 ||
    readString(data, ['otherUserName', 'other_user_name']).length > 0;
}

function pushSample(samples, limit, entry) {
  if (samples.length >= limit) return;
  samples.push(entry);
}

async function main() {
  const options = parsedOptions;
  const summary = {
    scanned: 0,
    missingPrimaryParticipants: 0,
    missingAnyParticipantArray: 0,
    inconsistentAliasArrays: 0,
    missingParticipantNames: 0,
    missingOfferMetadata: 0,
    hiddenWithoutRenderableContent: 0,
    orphanMapKeysWithoutParticipants: 0,
    zeroMessageButLastMessagePresent: 0,
    nonZeroMessageButNoLatestMetadata: 0,
    blockedConversations: 0,
    archivedConversations: 0,
    samples: {
      missingPrimaryParticipants: [],
      inconsistentAliasArrays: [],
      missingParticipantNames: [],
      missingOfferMetadata: [],
      hiddenWithoutRenderableContent: [],
      orphanMapKeysWithoutParticipants: [],
      zeroMessageButLastMessagePresent: [],
      nonZeroMessageButNoLatestMetadata: [],
    },
  };

  let query = db.collection('conversations').orderBy(admin.firestore.FieldPath.documentId()).limit(200);
  let lastDoc = null;

  while (true) {
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      summary.scanned += 1;
      const data = doc.data() || {};
      const canonicalParticipants = readArray(data, 'participants');
      const allParticipants = readParticipants(data);
      const aliasArrays = Object.fromEntries(
        PARTICIPANT_QUERY_FIELDS.map((field) => [field, readArray(data, field)]),
      );

      if (canonicalParticipants.length === 0) {
        summary.missingPrimaryParticipants += 1;
        pushSample(summary.samples.missingPrimaryParticipants, options.sampleSize, {
          id: doc.id,
          aliasArrays,
          participantMapKeys: Object.fromEntries(
            PARTICIPANT_MAP_FIELDS.map((field) => [field, readMapKeys(data, field)]),
          ),
        });
      }

      const hasAnyParticipantArray = Object.values(aliasArrays).some((values) => values.length > 0);
      if (!hasAnyParticipantArray) {
        summary.missingAnyParticipantArray += 1;
      }

      const normalizedCanonical = [...canonicalParticipants].sort();
      const inconsistentFields = Object.entries(aliasArrays)
        .filter(([field, values]) => field !== 'participants')
        .filter(([, values]) => JSON.stringify([...values].sort()) !== JSON.stringify(normalizedCanonical));
      if (canonicalParticipants.length > 0 && inconsistentFields.length > 0) {
        summary.inconsistentAliasArrays += 1;
        pushSample(summary.samples.inconsistentAliasArrays, options.sampleSize, {
          id: doc.id,
          participants: normalizedCanonical,
          inconsistentFields: Object.fromEntries(inconsistentFields),
        });
      }

      const participantNames = data.participantNames || data.participant_names || {};
      const participantNameKeys = Object.keys(participantNames).map((value) => normalizeString(value)).filter(Boolean);
      const missingParticipantNames = allParticipants.filter((participantId) => !participantNameKeys.includes(participantId));
      if (missingParticipantNames.length > 0) {
        summary.missingParticipantNames += 1;
        pushSample(summary.samples.missingParticipantNames, options.sampleSize, {
          id: doc.id,
          missingParticipantNames,
        });
      }

      const offerId = readString(data, ['offerId', 'offer_id']);
      const offerTitle = readString(data, ['offerTitle', 'offer_title']);
      if (!offerId || !offerTitle) {
        summary.missingOfferMetadata += 1;
        pushSample(summary.samples.missingOfferMetadata, options.sampleSize, {
          id: doc.id,
          offerId,
          offerTitle,
        });
      }

      if (!hasRenderableContent(data)) {
        summary.hiddenWithoutRenderableContent += 1;
        pushSample(summary.samples.hiddenWithoutRenderableContent, options.sampleSize, {
          id: doc.id,
          messageCount: readMessageCount(data),
          offerTitle,
          otherUserName: readString(data, ['otherUserName', 'other_user_name']),
        });
      }

      if (allParticipants.length === 0 && PARTICIPANT_MAP_FIELDS.some((field) => readMapKeys(data, field).length > 0)) {
        summary.orphanMapKeysWithoutParticipants += 1;
        pushSample(summary.samples.orphanMapKeysWithoutParticipants, options.sampleSize, {
          id: doc.id,
          participantMapKeys: Object.fromEntries(
            PARTICIPANT_MAP_FIELDS.map((field) => [field, readMapKeys(data, field)]),
          ),
        });
      }

      const messageCount = readMessageCount(data);
      const lastMessage = readString(data, ['lastMessage', 'last_message']);
      const lastSenderId = readString(data, ['lastSenderId', 'last_sender_id']);
      const lastSenderName = readString(data, ['lastSenderName', 'last_sender_name']);
      const lastMessageAt = parseDate(data.lastMessageAt ?? data.last_message_at);

      if (messageCount === 0 && lastMessage.length > 0) {
        summary.zeroMessageButLastMessagePresent += 1;
        pushSample(summary.samples.zeroMessageButLastMessagePresent, options.sampleSize, {
          id: doc.id,
          lastMessage,
        });
      }

      if (messageCount > 0 && (!lastMessage || !lastSenderId || !lastSenderName || lastMessageAt == null)) {
        summary.nonZeroMessageButNoLatestMetadata += 1;
        pushSample(summary.samples.nonZeroMessageButNoLatestMetadata, options.sampleSize, {
          id: doc.id,
          messageCount,
          lastMessage,
          lastSenderId,
          lastSenderName,
          lastMessageAt: lastMessageAt?.toISOString() ?? null,
        });
      }

      const blockedBy = data.blockedBy && typeof data.blockedBy === 'object' ? data.blockedBy : {};
      if (Object.values(blockedBy).some((value) => value === true)) {
        summary.blockedConversations += 1;
      }

      const archivedBy = data.archivedBy && typeof data.archivedBy === 'object' ? data.archivedBy : {};
      if (allParticipants.length > 0 && allParticipants.every((participantId) => archivedBy[participantId] === true)) {
        summary.archivedConversations += 1;
      }

      if (options.limit > 0 && summary.scanned >= options.limit) break;
      lastDoc = doc;
    }

    if (options.limit > 0 && summary.scanned >= options.limit) break;
    if (snapshot.size < 200) break;
    query = db.collection('conversations')
      .orderBy(admin.firestore.FieldPath.documentId())
      .startAfter(lastDoc)
      .limit(200);
  }

  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error('[audit_conversations_firestore] failed:', error);
  process.exitCode = 1;
});