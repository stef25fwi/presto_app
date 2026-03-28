const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const PARTICIPANT_QUERY_FIELDS = [
  'participants',
  'participant_ids',
  'participantIds',
  'userIds',
  'memberIds',
];
const PARTICIPANT_FIELDS = [...PARTICIPANT_QUERY_FIELDS];
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

function logStep(label, payload) {
  console.log(`\n[${label}]`);
  if (payload !== undefined) {
    console.log(typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2));
  }
}

function normalizeString(value) {
  return String(value ?? '').trim();
}

function parseDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function readConversationParticipants(data) {
  const result = [];
  const seen = new Set();

  const addParticipant = (value) => {
    const normalized = normalizeString(value);
    if (!normalized || seen.has(normalized)) return;
    seen.add(normalized);
    result.push(normalized);
  };

  for (const field of PARTICIPANT_FIELDS) {
    const raw = data[field];
    if (!Array.isArray(raw)) continue;
    for (const value of raw) addParticipant(value);
  }

  for (const field of PARTICIPANT_MAP_FIELDS) {
    const raw = data[field];
    if (!raw || typeof raw !== 'object') continue;
    for (const key of Object.keys(raw)) addParticipant(key);
  }

  result.sort();
  return result;
}

function readString(data, keys) {
  for (const key of keys) {
    const value = normalizeString(data[key]);
    if (value) return value;
  }
  return '';
}

function readBoolMap(data, keys) {
  for (const key of keys) {
    const raw = data[key];
    if (!raw || typeof raw !== 'object') continue;
    const result = {};
    for (const [entryKey, entryValue] of Object.entries(raw)) {
      const normalizedKey = normalizeString(entryKey);
      if (!normalizedKey) continue;
      result[normalizedKey] = entryValue === true;
    }
    return result;
  }
  return {};
}

function readIntMap(data, keys) {
  for (const key of keys) {
    const raw = data[key];
    if (!raw || typeof raw !== 'object') continue;
    const result = {};
    for (const [entryKey, entryValue] of Object.entries(raw)) {
      const normalizedKey = normalizeString(entryKey);
      const intValue = typeof entryValue === 'number'
        ? entryValue
        : Number.parseInt(String(entryValue ?? ''), 10);
      if (!normalizedKey || Number.isNaN(intValue)) continue;
      result[normalizedKey] = intValue;
    }
    return result;
  }
  return {};
}

function readMessageCount(data) {
  const rawCount = data.messageCount ?? data.message_count;
  if (typeof rawCount === 'number' && Number.isFinite(rawCount) && rawCount >= 0) {
    return Math.floor(rawCount);
  }
  return readString(data, ['lastMessage', 'last_message']) ? 1 : 0;
}

function toSummary(docId, data) {
  return {
    id: docId,
    participants: readConversationParticipants(data),
    participantNames: data.participantNames || data.participant_names || {},
    offerId: readString(data, ['offerId', 'offer_id']),
    offerTitle: readString(data, ['offerTitle', 'offer_title']),
    otherUserName: readString(data, ['otherUserName', 'other_user_name']),
    lastMessage: readString(data, ['lastMessage', 'last_message']),
    lastSenderId: readString(data, ['lastSenderId', 'last_sender_id']),
    lastSenderName: readString(data, ['lastSenderName', 'last_sender_name']),
    unreadCount: readIntMap(data, ['unreadCount', 'unread_count']),
    archivedBy: readBoolMap(data, ['archivedBy']),
    blockedBy: readBoolMap(data, ['blockedBy']),
    messageCount: readMessageCount(data),
    createdAt: parseDate(data.createdAt ?? data.created_at),
    updatedAt: parseDate(data.updatedAt ?? data.updated_at),
    lastMessageAt: parseDate(data.lastMessageAt ?? data.last_message_at),
    rawParticipantArrays: {
      participants: data.participants || null,
      participant_ids: data.participant_ids || null,
      participantIds: data.participantIds || null,
      userIds: data.userIds || null,
      memberIds: data.memberIds || null,
    },
    rawParticipantMapKeys: {
      participantNames: Object.keys(data.participantNames || data.participant_names || {}),
      unreadCount: Object.keys(data.unreadCount || data.unread_count || {}),
      lastReadAt: Object.keys(data.lastReadAt || data.last_read_at || {}),
      archivedBy: Object.keys(data.archivedBy || {}),
      blockedBy: Object.keys(data.blockedBy || {}),
    },
  };
}

function includesUser(summary, userId) {
  return summary.participants.includes(normalizeString(userId));
}

function hasRenderableContent(summary) {
  return summary.messageCount > 0 ||
    summary.lastMessage.length > 0 ||
    summary.lastMessageAt != null ||
    summary.offerTitle.length > 0 ||
    summary.otherUserName.length > 0;
}

function isArchivedForUser(summary, userId) {
  return summary.archivedBy[normalizeString(userId)] === true;
}

async function inspectForUser(userId, conversationId) {
  const snapshots = await Promise.all(
    PARTICIPANT_QUERY_FIELDS.map((field) =>
      db.collection('conversations')
        .where(field, 'array-contains', userId)
        .get(),
    ),
  );

  const docsPerField = {};
  const foundInFields = [];
  let fetched = false;

  snapshots.forEach((snapshot, index) => {
    const field = PARTICIPANT_QUERY_FIELDS[index];
    const ids = snapshot.docs.map((doc) => doc.id);
    docsPerField[field] = ids;
    if (ids.includes(conversationId)) {
      fetched = true;
      foundInFields.push(field);
    }
  });

  const snap = await db.collection('conversations').doc(conversationId).get();
  const summary = snap.exists ? toSummary(snap.id, snap.data() || {}) : null;

  return {
    userId,
    fetchedByQueries: fetched,
    foundInFields,
    includesUser: summary ? includesUser(summary, userId) : false,
    hasRenderableContent: summary ? hasRenderableContent(summary) : false,
    archivedForUser: summary ? isArchivedForUser(summary, userId) : false,
    visibleInMessagesPage: summary
      ? fetched && includesUser(summary, userId) && hasRenderableContent(summary) && !isArchivedForUser(summary, userId)
      : false,
    docsPerField,
  };
}

function parseConversationIdParts(conversationId) {
  const normalized = normalizeString(conversationId);
  if (!normalized.startsWith('offer_')) {
    return {
      offerId: '',
      participantIds: [],
    };
  }

  const withoutPrefix = normalized.slice('offer_'.length);
  const parts = withoutPrefix.split('__').filter(Boolean);
  if (parts.length < 3) {
    return {
      offerId: '',
      participantIds: [],
    };
  }

  return {
    offerId: parts[0],
    participantIds: parts.slice(1),
  };
}

async function findCandidateConversations({ offerId, participantIds }) {
  const candidateDocs = new Map();

  if (offerId) {
    const offerSnapshots = await Promise.all([
      db.collection('conversations').where('offerId', '==', offerId).get(),
      db.collection('conversations').where('offer_id', '==', offerId).get(),
    ]);
    for (const snapshot of offerSnapshots) {
      for (const doc of snapshot.docs) {
        candidateDocs.set(doc.id, doc);
      }
    }
  }

  for (const participantId of participantIds) {
    const snapshots = await Promise.all(
      PARTICIPANT_QUERY_FIELDS.map((field) =>
        db.collection('conversations').where(field, 'array-contains', participantId).get(),
      ),
    );
    for (const snapshot of snapshots) {
      for (const doc of snapshot.docs) {
        candidateDocs.set(doc.id, doc);
      }
    }
  }

  const summaries = [...candidateDocs.values()]
    .map((doc) => toSummary(doc.id, doc.data() || {}))
    .filter((summary) => {
      const matchesOffer = !offerId || summary.offerId === offerId;
      const matchesParticipants = participantIds.length === 0 || participantIds.every((participantId) => summary.participants.includes(participantId));
      return matchesOffer || matchesParticipants;
    })
    .sort((left, right) => {
      const leftDate = left.lastMessageAt || left.updatedAt || left.createdAt || '';
      const rightDate = right.lastMessageAt || right.updatedAt || right.createdAt || '';
      return String(rightDate).localeCompare(String(leftDate));
    });

  return summaries;
}

async function inspectRelatedEntities({ offerId, participantIds }) {
  const [offerSnap, listingSnap, userDocs, authUsers] = await Promise.all([
    offerId ? db.collection('offers').doc(offerId).get() : Promise.resolve(null),
    offerId ? db.collection('listings').doc(offerId).get() : Promise.resolve(null),
    Promise.all(
      participantIds.map(async (participantId) => {
        const doc = await db.collection('users').doc(participantId).get();
        return {
          participantId,
          exists: doc.exists,
          displayName: normalizeString(doc.data()?.displayName || doc.data()?.display_name),
          email: normalizeString(doc.data()?.email),
          status: normalizeString(doc.data()?.status),
        };
      }),
    ),
    Promise.all(
      participantIds.map(async (participantId) => {
        try {
          const user = await admin.auth().getUser(participantId);
          return {
            participantId,
            exists: true,
            email: normalizeString(user.email),
            displayName: normalizeString(user.displayName),
            disabled: user.disabled === true,
          };
        } catch (error) {
          return {
            participantId,
            exists: false,
            errorCode: normalizeString(error && error.code),
          };
        }
      }),
    ),
  ]);

  return {
    offer: offerSnap == null ? null : {
      exists: offerSnap.exists,
      title: normalizeString(offerSnap.data()?.title),
      ownerId: normalizeString(offerSnap.data()?.ownerId || offerSnap.data()?.userId || offerSnap.data()?.uid),
      status: normalizeString(offerSnap.data()?.status),
    },
    listing: listingSnap == null ? null : {
      exists: listingSnap.exists,
      title: normalizeString(listingSnap.data()?.title),
      ownerId: normalizeString(listingSnap.data()?.ownerId || listingSnap.data()?.userId || listingSnap.data()?.uid),
      status: normalizeString(listingSnap.data()?.status),
    },
    userDocs,
    authUsers,
  };
}

async function main() {
  const conversationId = normalizeString(process.argv[2]);
  if (!conversationId) {
    throw new Error('Usage: node tools/inspect_conversation_visibility.cjs <conversationId>');
  }

  const snap = await db.collection('conversations').doc(conversationId).get();
  if (!snap.exists) {
    const parsed = parseConversationIdParts(conversationId);
    const candidates = await findCandidateConversations(parsed);
    const relatedEntities = await inspectRelatedEntities(parsed);
    logStep('conversationMissing', {
      conversationId,
      parsed,
      candidateCount: candidates.length,
      candidates,
      relatedEntities,
    });
    throw new Error(`Conversation not found: ${conversationId}`);
  }

  const raw = snap.data() || {};
  const summary = toSummary(snap.id, raw);

  logStep('conversationSummary', summary);

  const participantIds = summary.participants;
  const perUser = [];
  for (const userId of participantIds) {
    perUser.push(await inspectForUser(userId, conversationId));
  }

  logStep('perUserVisibility', perUser);

  const messagesSnap = await snap.ref.collection('messages').orderBy('createdAt', 'asc').limit(10).get();
  logStep('messages', messagesSnap.docs.map((doc) => ({
    id: doc.id,
    senderId: doc.data().senderId || doc.data().sender_id || null,
    text: doc.data().text || doc.data().body || null,
    createdAt: parseDate(doc.data().createdAt || doc.data().created_at),
  })));
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});