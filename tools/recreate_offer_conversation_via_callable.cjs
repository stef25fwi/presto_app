const admin = require('../functions/node_modules/firebase-admin');
const {
  buildConversationMirrorFields,
} = require('../functions/lib/modules/messaging/mirror.js');

const API_KEY = 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo';
const PROJECT_ID = 'presto-app-74abe';
const CALLABLE_BASE_URL = `https://europe-west1-${PROJECT_ID}.cloudfunctions.net`;

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

function canonicalConversationId({ offerId, currentUserId, otherUserId }) {
  return `offer_${offerId.replaceAll('/', '_')}__${[currentUserId, otherUserId]
    .map((value) => value.replaceAll('/', '_'))
    .sort()
    .join('__')}`;
}

async function signInWithCustomToken(customToken) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${API_KEY}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token: customToken,
        returnSecureToken: true,
      }),
    },
  );

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`signInWithCustomToken failed: ${response.status} ${JSON.stringify(data)}`);
  }
  return data;
}

async function callCallable(name, idToken, data) {
  const response = await fetch(`${CALLABLE_BASE_URL}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data }),
  });

  const payload = await response.json();
  if (!response.ok || payload.error) {
    throw new Error(`${name} failed: ${response.status} ${JSON.stringify(payload)}`);
  }
  return payload.result;
}

function readDisplayName(userDoc, authUser, fallback) {
  return normalizeString(
    userDoc?.displayName ||
    userDoc?.display_name ||
    userDoc?.name ||
    authUser?.displayName ||
    authUser?.email ||
    fallback,
  );
}

async function main() {
  const offerId = normalizeString(process.argv[2]);
  const currentUserId = normalizeString(process.argv[3]);
  const otherUserId = normalizeString(process.argv[4]);

  if (!offerId || !currentUserId || !otherUserId) {
    throw new Error('Usage: node tools/recreate_offer_conversation_via_callable.cjs <offerId> <currentUserId> <otherUserId>');
  }

  const expectedConversationId = canonicalConversationId({
    offerId,
    currentUserId,
    otherUserId,
  });

  const [offerSnap, currentUserDoc, otherUserDoc, currentAuthUser, otherAuthUser] = await Promise.all([
    db.collection('offers').doc(offerId).get(),
    db.collection('users').doc(currentUserId).get(),
    db.collection('users').doc(otherUserId).get(),
    admin.auth().getUser(currentUserId),
    admin.auth().getUser(otherUserId),
  ]);

  if (!offerSnap.exists) {
    throw new Error(`Offer not found: ${offerId}`);
  }

  const offerData = offerSnap.data() || {};
  const offerTitle = normalizeString(offerData.title);
  const currentUserName = readDisplayName(currentUserDoc.data(), currentAuthUser, currentUserId);
  const otherUserName = readDisplayName(otherUserDoc.data(), otherAuthUser, otherUserId);

  logStep('inputs', {
    offerId,
    offerTitle,
    currentUserId,
    currentUserName,
    otherUserId,
    otherUserName,
    expectedConversationId,
  });

  let ensureResult;
  let recreationMode = 'callable';

  try {
    const customToken = await admin.auth().createCustomToken(currentUserId);
    const session = await signInWithCustomToken(customToken);

    ensureResult = await callCallable('ensureOfferConversation', session.idToken, {
      offerId,
      offerTitle,
      otherUserId,
      currentUserName,
      otherUserName,
    });
  } catch (error) {
    recreationMode = 'admin-fallback';
    logStep('callableFallback', {
      reason: normalizeString(error && error.message),
      note: 'Custom token indisponible dans cet environnement, recreation admin directe du document conversation.',
    });

    const convRef = db.collection('conversations').doc(expectedConversationId);
    await convRef.set(
      buildConversationMirrorFields({
        participants: [currentUserId, otherUserId].sort(),
        participantNames: {
          [currentUserId]: currentUserName,
          [otherUserId]: otherUserName,
        },
        otherUserName,
        offerId,
        offerTitle,
        status: 'open',
        archivedBy: {},
        blockedBy: {},
        lastReadAt: {},
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: '',
        lastSenderId: '',
        lastSenderName: '',
        messageCount: 0,
        unreadCount: {
          [currentUserId]: 0,
          [otherUserId]: 0,
        },
      }),
      { merge: true },
    );

    ensureResult = {
      ok: true,
      conversationId: expectedConversationId,
      offerTitle,
      recreatedVia: recreationMode,
    };
  }

  const conversationId = normalizeString(ensureResult.conversationId);
  const conversationSnap = await db.collection('conversations').doc(conversationId).get();
  const conversation = conversationSnap.data() || {};

  logStep('ensureResult', {
    ...ensureResult,
    recreationMode,
  });
  logStep('conversationDoc', {
    exists: conversationSnap.exists,
    conversationId,
    expectedConversationId,
    matchesExpected: conversationId === expectedConversationId,
    participants: conversation.participants || null,
    participant_ids: conversation.participant_ids || null,
    participantIds: conversation.participantIds || null,
    userIds: conversation.userIds || null,
    memberIds: conversation.memberIds || null,
    offerId: conversation.offerId || conversation.offer_id || null,
    offerTitle: conversation.offerTitle || conversation.offer_title || null,
    otherUserName: conversation.otherUserName || conversation.other_user_name || null,
    messageCount: conversation.messageCount || conversation.message_count || 0,
  });
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});