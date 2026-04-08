const admin = require('../functions/node_modules/firebase-admin');
const { verifySeededMessagesVisibility } = require('./verify_messages_list_visibility.cjs');

const API_KEY = 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo';
const PROJECT_ID = 'presto-app-74abe';
const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || 'europe-west1';
const CALLABLE_BASE_URL = `https://${FUNCTIONS_REGION}-${PROJECT_ID}.cloudfunctions.net`;
const SEED_TAG = 'messaging-test-20260328';
const BUYER_EMAIL = process.env.TEST_BUYER_EMAIL || 'messaging.buyer.20260328@presto-app.test';
const BUYER_PASSWORD = process.env.TEST_BUYER_PASSWORD || 'PrestoBuyer!2026';
const SELLER_EMAIL = process.env.TEST_SELLER_EMAIL || 'messaging.seller.20260328@presto-app.test';
const SELLER_PASSWORD = process.env.TEST_SELLER_PASSWORD || 'PrestoSeller!2026';

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

async function upsertAuthUser({ email, password, displayName }) {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(existing.uid, {
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });
    return admin.auth().getUser(existing.uid);
  } catch (error) {
    if (error && error.code === 'auth/user-not-found') {
      return admin.auth().createUser({
        email,
        password,
        displayName,
        emailVerified: true,
        disabled: false,
      });
    }
    throw error;
  }
}

async function upsertUserDoc(userRecord, roleLabel) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('users').doc(userRecord.uid).set({
    uid: userRecord.uid,
    userId: userRecord.uid,
    email: String(userRecord.email || '').trim().toLowerCase(),
    displayName: String(userRecord.displayName || roleLabel).trim(),
    display_name: String(userRecord.displayName || roleLabel).trim(),
    pseudo: String(userRecord.displayName || roleLabel).trim(),
    status: 'active',
    seedTag: SEED_TAG,
    updatedAt: now,
    createdAt: now,
    inboxCounts: {
      unreadMessages: 0,
      unreadNotifications: 0,
      totalUnread: 0,
      updatedAt: now,
    },
  }, { merge: true });
}

async function signInWithPassword(email, password) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true,
      }),
    },
  );

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`signInWithPassword failed for ${email}: ${response.status} ${JSON.stringify(data)}`);
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

async function createOffer({ sellerUser, title }) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const ref = db.collection('offers').doc();
  await ref.set({
    title,
    description: 'Annonce de test créée automatiquement pour valider le pipeline de messagerie.',
    advertiserName: sellerUser.displayName || 'Annonceur Test',
    userId: sellerUser.uid,
    ownerId: sellerUser.uid,
    uid: sellerUser.uid,
    status: 'active',
    isActive: true,
    isPublished: true,
    visibility: { isPublic: true },
    city: 'Paris',
    postalCode: '75001',
    category: 'services',
    price: 42,
    currency: 'EUR',
    seedTag: SEED_TAG,
    createdAt: now,
    updatedAt: now,
  });
  return ref;
}

async function main() {
  const buyerRecord = await upsertAuthUser({
    email: BUYER_EMAIL,
    password: BUYER_PASSWORD,
    displayName: 'Acheteur Test Messagerie',
  });
  const sellerRecord = await upsertAuthUser({
    email: SELLER_EMAIL,
    password: SELLER_PASSWORD,
    displayName: 'Annonceur Test Messagerie',
  });

  await Promise.all([
    upsertUserDoc(buyerRecord, 'Acheteur Test Messagerie'),
    upsertUserDoc(sellerRecord, 'Annonceur Test Messagerie'),
  ]);

  logStep('accounts', {
    buyer: {
      uid: buyerRecord.uid,
      email: buyerRecord.email,
      password: BUYER_PASSWORD,
      displayName: buyerRecord.displayName,
    },
    seller: {
      uid: sellerRecord.uid,
      email: sellerRecord.email,
      password: SELLER_PASSWORD,
      displayName: sellerRecord.displayName,
    },
  });

  const offerTitle = `Annonce test messagerie ${new Date().toISOString()}`;
  const offerRef = await createOffer({
    sellerUser: sellerRecord,
    title: offerTitle,
  });

  logStep('offer', {
    offerId: offerRef.id,
    title: offerTitle,
    ownerId: sellerRecord.uid,
  });

  const [buyerSession, sellerSession] = await Promise.all([
    signInWithPassword(BUYER_EMAIL, BUYER_PASSWORD),
    signInWithPassword(SELLER_EMAIL, SELLER_PASSWORD),
  ]);

  const ensureResult = await callCallable('ensureOfferConversation', buyerSession.idToken, {
    offerId: offerRef.id,
    offerTitle,
    otherUserId: sellerRecord.uid,
    currentUserName: buyerRecord.displayName,
    otherUserName: sellerRecord.displayName,
  });

  const conversationId = String(ensureResult.conversationId || '').trim();
  if (!conversationId) {
    throw new Error('Conversation ID missing from ensureOfferConversation result');
  }

  logStep('conversation', {
    conversationId,
    ensureResult,
  });

  const firstMessage = `Bonjour, je vous contacte pour ${offerTitle}.`;
  const secondMessage = 'Bonjour, oui bien sûr, je suis disponible pour échanger.';

  const firstSend = await callCallable('sendConversationMessage', buyerSession.idToken, {
    conversationId,
    text: firstMessage,
  });

  const secondSend = await callCallable('sendConversationMessage', sellerSession.idToken, {
    conversationId,
    text: secondMessage,
  });

  const conversationSnap = await db.collection('conversations').doc(conversationId).get();
  const conversation = conversationSnap.data() || {};
  const messagesSnap = await conversationSnap.ref
    .collection('messages')
    .orderBy('createdAt', 'asc')
    .limit(10)
    .get();

  logStep('verification', {
    lastMessage: conversation.lastMessage || conversation.last_message || null,
    lastSenderId: conversation.lastSenderId || conversation.last_sender_id || null,
    unreadCount: conversation.unreadCount || conversation.unread_count || null,
    participants: conversation.participants || null,
    participant_ids: conversation.participant_ids || null,
    participantIds: conversation.participantIds || null,
    userIds: conversation.userIds || null,
    memberIds: conversation.memberIds || null,
    messageIds: [firstSend.messageId, secondSend.messageId],
    messages: messagesSnap.docs.map((doc) => ({
      id: doc.id,
      senderId: doc.data().senderId || doc.data().sender_id || null,
      text: doc.data().text || doc.data().body || null,
    })),
  });

  logStep('summary', {
    seedTag: SEED_TAG,
    buyerEmail: BUYER_EMAIL,
    buyerPassword: BUYER_PASSWORD,
    sellerEmail: SELLER_EMAIL,
    sellerPassword: SELLER_PASSWORD,
    offerId: offerRef.id,
    conversationId,
  });

  await verifySeededMessagesVisibility();
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});