const admin = require('../functions/node_modules/firebase-admin');

const FIREBASE_WEB_API_KEY = process.env.FIREBASE_WEB_API_KEY || '';
const PROJECT_ID = 'presto-app-74abe';
const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || 'europe-west1';
const CALLABLE_BASE_URL = `https://${FUNCTIONS_REGION}-${PROJECT_ID}.cloudfunctions.net`;
const TARGET_UID = (process.env.MESSAGING_TARGET_UID || '').trim();
const TEST_EMAIL = (process.env.MESSAGING_TEST_EMAIL || '').trim().toLowerCase();
const TEST_PASSWORD = process.env.MESSAGING_TEST_PASSWORD || '';
const TEST_DISPLAY_NAME = process.env.MESSAGING_TEST_DISPLAY_NAME || 'Profil Test Messagerie';
const SEED_TAG = process.env.MESSAGING_SEED_TAG || 'messaging-generic-test';

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

function assertRequiredEnv() {
  const missing = [];
  if (!FIREBASE_WEB_API_KEY) missing.push('FIREBASE_WEB_API_KEY');
  if (!TARGET_UID) missing.push('MESSAGING_TARGET_UID');
  if (!TEST_EMAIL) missing.push('MESSAGING_TEST_EMAIL');
  if (!TEST_PASSWORD) missing.push('MESSAGING_TEST_PASSWORD');
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function upsertAuthUser({ email, password, displayName }) {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(existing.uid, {
      email,
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

async function upsertUserDoc(userRecord, seedTag) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const displayName = normalizeString(userRecord.displayName);
  await db.collection('users').doc(userRecord.uid).set({
    uid: userRecord.uid,
    userId: userRecord.uid,
    email: normalizeString(userRecord.email).toLowerCase(),
    displayName,
    display_name: displayName,
    pseudo: displayName,
    status: 'active',
    seedTag,
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

function readDisplayName(userDoc, authUser, fallback) {
  return normalizeString(
    userDoc?.displayName ||
    userDoc?.display_name ||
    userDoc?.pseudo ||
    authUser?.displayName ||
    authUser?.email ||
    fallback,
  );
}

async function signInWithPassword(email, password) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );

  const data = await response.json();
  if (!response.ok) {
    throw new Error(`signInWithPassword failed: ${response.status} ${JSON.stringify(data)}`);
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

async function createOfferForTarget(targetName) {
  const offerRef = db.collection('offers').doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const title = `Conversation test ${new Date().toISOString()}`;

  await offerRef.set({
    title,
    description: 'Annonce créée automatiquement pour tester une conversation entre un compte cible et un profil de test.',
    advertiserName: targetName,
    userId: TARGET_UID,
    ownerId: TARGET_UID,
    uid: TARGET_UID,
    status: 'active',
    isActive: true,
    isPublished: true,
    visibility: { isPublic: true },
    city: 'Paris',
    postalCode: '75001',
    category: 'services',
    price: 20,
    currency: 'EUR',
    seedTag: SEED_TAG,
    createdAt: now,
    updatedAt: now,
  });

  return { offerId: offerRef.id, title };
}

async function waitForNotification({ userId, conversationId }) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const snap = await db.collection('notifications')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    const match = snap.docs.find((doc) => {
      const data = doc.data() || {};
      return normalizeString(data.conversationId) === conversationId;
    });
    if (match) return { id: match.id, ...match.data() };
    await sleep(1000);
  }
  return null;
}

async function waitForEmailEvent({ userId, conversationId }) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const snap = await db.collection('email_events')
      .orderBy('occurred_at', 'desc')
      .limit(20)
      .get();

    const match = snap.docs.find((doc) => {
      const data = doc.data() || {};
      return normalizeString(data.recipient_user_id) === userId &&
        normalizeString(data.source_id) === conversationId;
    });
    if (match) return { id: match.id, ...match.data() };
    await sleep(1000);
  }
  return null;
}

async function inspectMessagesVisibility({ userId, conversationId }) {
  const snapshot = await db.collection('conversations')
    .where('participants', 'array-contains', userId)
    .get();
  const ids = snapshot.docs.map((doc) => doc.id);
  return {
    fetchedConversationIds: ids,
    conversationVisibleByParticipantsQuery: ids.includes(conversationId),
  };
}

async function main() {
  assertRequiredEnv();

  const [targetAuth, targetDocSnap] = await Promise.all([
    admin.auth().getUser(TARGET_UID),
    db.collection('users').doc(TARGET_UID).get(),
  ]);

  const targetName = readDisplayName(
    targetDocSnap.data(),
    targetAuth,
    'Utilisateur cible',
  );

  const testUser = await upsertAuthUser({
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
    displayName: TEST_DISPLAY_NAME,
  });
  await upsertUserDoc(testUser, SEED_TAG);

  const offer = await createOfferForTarget(targetName);
  const testSession = await signInWithPassword(TEST_EMAIL, TEST_PASSWORD);

  const ensureResult = await callCallable('ensureOfferConversation', testSession.idToken, {
    offerId: offer.offerId,
    offerTitle: offer.title,
    otherUserId: TARGET_UID,
    currentUserName: TEST_DISPLAY_NAME,
    otherUserName: targetName,
  });

  const conversationId = normalizeString(ensureResult.conversationId);
  if (!conversationId) {
    throw new Error('Conversation ID missing from ensureOfferConversation result');
  }

  const firstMessage = `Bonjour ${targetName}, ceci est une conversation de test créée automatiquement.`;
  const sendResult = await callCallable('sendConversationMessage', testSession.idToken, {
    conversationId,
    text: firstMessage,
  });

  const conversationSnap = await db.collection('conversations').doc(conversationId).get();
  const conversation = conversationSnap.data() || {};
  const messagesSnap = await conversationSnap.ref
    .collection('messages')
    .orderBy('createdAt', 'asc')
    .limit(10)
    .get();
  const [targetUserAfter, inAppNotification, emailEvent, visibility] = await Promise.all([
    db.collection('users').doc(TARGET_UID).get(),
    waitForNotification({ userId: TARGET_UID, conversationId }),
    waitForEmailEvent({ userId: TARGET_UID, conversationId }),
    inspectMessagesVisibility({ userId: TARGET_UID, conversationId }),
  ]);
  const [pushPrefsSnap, pushTokensSnap] = await Promise.all([
    db.collection('notification_preferences').doc(TARGET_UID).get(),
    db.collection('users').doc(TARGET_UID).collection('push_tokens').get(),
  ]);

  logStep('target', {
    uid: TARGET_UID,
    displayName: targetName,
    email: targetAuth.email || null,
  });
  logStep('testProfile', {
    uid: testUser.uid,
    email: TEST_EMAIL,
    displayName: TEST_DISPLAY_NAME,
  });
  logStep('offer', offer);
  logStep('conversation', {
    conversationId,
    messageId: sendResult.messageId || null,
    participants: conversation.participants || null,
    offerId: conversation.offerId || conversation.offer_id || null,
    offerTitle: conversation.offerTitle || conversation.offer_title || null,
    lastMessage: conversation.lastMessage || conversation.last_message || null,
    unreadCount: conversation.unreadCount || conversation.unread_count || null,
    messages: messagesSnap.docs.map((doc) => ({
      id: doc.id,
      senderId: doc.data().senderId || doc.data().sender_id || null,
      text: doc.data().text || doc.data().body || null,
    })),
  });
  logStep('targetInbox', {
    inboxCounts: targetUserAfter.data()?.inboxCounts || null,
  });
  logStep('targetNotification', inAppNotification
    ? {
        id: inAppNotification.id,
        title: inAppNotification.title || null,
        message: inAppNotification.message || null,
        type: inAppNotification.type || null,
        read: inAppNotification.read || false,
        routeName: inAppNotification.routeName || null,
        conversationId: inAppNotification.conversationId || null,
      }
    : 'Aucune notification in-app trouvée après polling.');
  logStep('targetEmailEvent', emailEvent
    ? {
        id: emailEvent.id,
        event_name: emailEvent.event_name || null,
        recipient_user_id: emailEvent.recipient_user_id || null,
        source_id: emailEvent.source_id || null,
      }
    : 'Aucun email_event trouvé après polling.');
  logStep('targetMessagesVisibility', visibility);
  logStep('targetPushState', {
    notificationPreferences: pushPrefsSnap.exists ? (pushPrefsSnap.data() || {}) : null,
    pushTokenCount: pushTokensSnap.size,
    pushTokens: pushTokensSnap.docs.map((doc) => ({
      id: doc.id,
      enabled: doc.data().enabled !== false,
      platform: doc.data().platform || null,
      updatedAt: doc.data().updatedAt || doc.data().updated_at || null,
    })),
  });
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});