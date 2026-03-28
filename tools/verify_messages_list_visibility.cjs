const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const SEED_TAG = 'messaging-test-20260328';
const BUYER_EMAIL = process.env.TEST_BUYER_EMAIL || 'messaging.buyer.20260328@presto-app.test';
const SELLER_EMAIL = process.env.TEST_SELLER_EMAIL || 'messaging.seller.20260328@presto-app.test';
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

function parseDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function readMessageCount(data) {
  const rawCount = data.messageCount ?? data.message_count;
  if (typeof rawCount === 'number' && Number.isFinite(rawCount) && rawCount >= 0) {
    return Math.floor(rawCount);
  }
  return readString(data, ['lastMessage', 'last_message']) ? 1 : 0;
}

function toConversationSummary(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    participants: readConversationParticipants(data),
    otherUserName: readString(data, ['otherUserName', 'other_user_name']),
    offerTitle: readString(data, ['offerTitle', 'offer_title']),
    lastMessage: readString(data, ['lastMessage', 'last_message']),
    lastSenderId: readString(data, ['lastSenderId', 'last_sender_id']),
    unreadCount: readIntMap(data, ['unreadCount', 'unread_count']),
    messageCount: readMessageCount(data),
    lastMessageAt: parseDate(data.lastMessageAt ?? data.last_message_at),
    updatedAt: parseDate(data.updatedAt ?? data.updated_at),
    createdAt: parseDate(data.createdAt ?? data.created_at),
    archivedBy: readBoolMap(data, ['archivedBy']),
    blockedBy: readBoolMap(data, ['blockedBy']),
  };
}

function includesUser(conversation, userId) {
  return conversation.participants.includes(normalizeString(userId));
}

function isArchivedForUser(conversation, userId) {
  return conversation.archivedBy[normalizeString(userId)] === true;
}

function unreadForUser(conversation, userId) {
  return conversation.unreadCount[normalizeString(userId)] || 0;
}

function hasRenderableContent(conversation) {
  return conversation.messageCount > 0 ||
    conversation.lastMessage.length > 0 ||
    conversation.lastMessageAt != null ||
    conversation.offerTitle.length > 0 ||
    conversation.otherUserName.length > 0;
}

function canonicalConversationId({ offerId, currentUserId, otherUserId }) {
  return `offer_${offerId.replaceAll('/', '_')}__${[currentUserId, otherUserId]
    .map((value) => value.replaceAll('/', '_'))
    .sort()
    .join('__')}`;
}

async function loadSeedScenario({ buyerUid, sellerUid }) {
  const offersSnap = await db.collection('offers').where('seedTag', '==', SEED_TAG).get();
  const offers = offersSnap.docs
    .map((doc) => ({ id: doc.id, data: doc.data() || {} }))
    .filter((entry) => normalizeString(entry.data.ownerId) === sellerUid)
    .sort((left, right) => {
      const leftDate = parseDate(left.data.updatedAt) || parseDate(left.data.createdAt) || new Date(0);
      const rightDate = parseDate(right.data.updatedAt) || parseDate(right.data.createdAt) || new Date(0);
      return rightDate.getTime() - leftDate.getTime();
    });

  if (offers.length === 0) {
    throw new Error(`No offer found for seedTag=${SEED_TAG}`);
  }

  const latestOffer = offers[0];
  const conversationId = canonicalConversationId({
    offerId: latestOffer.id,
    currentUserId: buyerUid,
    otherUserId: sellerUid,
  });

  return {
    offerId: latestOffer.id,
    conversationId,
    offerTitle: normalizeString(latestOffer.data.title),
  };
}

async function collectConversationStateForUser(userId, expectedConversationId) {
  const snapshots = await Promise.all(
    PARTICIPANT_QUERY_FIELDS.map((field) =>
      db.collection('conversations')
        .where(field, 'array-contains', userId)
        .get(),
    ),
  );

  const docsById = new Map();
  const docsPerField = {};

  snapshots.forEach((snapshot, index) => {
    const field = PARTICIPANT_QUERY_FIELDS[index];
    docsPerField[field] = snapshot.docs.map((doc) => doc.id);
    for (const doc of snapshot.docs) {
      if (!docsById.has(doc.id)) docsById.set(doc.id, doc);
    }
  });

  const allConversations = [...docsById.values()].map(toConversationSummary);
  const visibleConversations = allConversations.filter((conversation) => {
    if (!includesUser(conversation, userId)) return false;
    if (!hasRenderableContent(conversation)) return false;
    if (isArchivedForUser(conversation, userId)) return false;
    return true;
  });

  const expectedDocSnap = await db.collection('conversations').doc(expectedConversationId).get();
  const expectedData = expectedDocSnap.exists ? toConversationSummary(expectedDocSnap) : null;

  return {
    userId,
    docsPerField,
    totalFetchedConversationIds: allConversations.map((conversation) => conversation.id),
    visibleConversationIds: visibleConversations.map((conversation) => conversation.id),
    expectedConversationFetched: docsById.has(expectedConversationId),
    expectedConversationVisible: visibleConversations.some((conversation) => conversation.id === expectedConversationId),
    expectedConversationDirectReadable: expectedData != null && includesUser(expectedData, userId),
    expectedConversationArchived: expectedData != null ? isArchivedForUser(expectedData, userId) : null,
    expectedConversationRenderable: expectedData != null ? hasRenderableContent(expectedData) : null,
    expectedConversationUnread: expectedData != null ? unreadForUser(expectedData, userId) : null,
  };
}

async function verifySeededMessagesVisibility() {
  const [buyerUser, sellerUser] = await Promise.all([
    admin.auth().getUserByEmail(BUYER_EMAIL),
    admin.auth().getUserByEmail(SELLER_EMAIL),
  ]);

  const scenario = await loadSeedScenario({
    buyerUid: buyerUser.uid,
    sellerUid: sellerUser.uid,
  });

  logStep('scenario', {
    buyerUid: buyerUser.uid,
    sellerUid: sellerUser.uid,
    offerId: scenario.offerId,
    offerTitle: scenario.offerTitle,
    conversationId: scenario.conversationId,
  });

  const [buyerState, sellerState] = await Promise.all([
    collectConversationStateForUser(buyerUser.uid, scenario.conversationId),
    collectConversationStateForUser(sellerUser.uid, scenario.conversationId),
  ]);

  logStep('buyerMessagesListState', buyerState);
  logStep('sellerMessagesListState', sellerState);

  const buyerOk = buyerState.expectedConversationFetched && buyerState.expectedConversationVisible;
  const sellerOk = sellerState.expectedConversationFetched && sellerState.expectedConversationVisible;

  if (!buyerOk || !sellerOk) {
    throw new Error(
      `Messages list visibility failed: buyerOk=${buyerOk} sellerOk=${sellerOk}`,
    );
  }

  logStep('result', 'La conversation seedee est visible dans la logique exacte de Mes messages pour les deux comptes.');

  return {
    scenario,
    buyerState,
    sellerState,
  };
}

module.exports = {
  verifySeededMessagesVisibility,
};

if (require.main === module) {
  verifySeededMessagesVisibility().catch((error) => {
    console.error('\n[error]');
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  });
}