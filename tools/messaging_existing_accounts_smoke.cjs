const admin = require('../functions/node_modules/firebase-admin');

const API_KEY = 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo';
const PROJECT_ID = 'presto-app-74abe';
const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || 'us-east1';
const CALLABLE_BASE_URL = `https://${FUNCTIONS_REGION}-${PROJECT_ID}.cloudfunctions.net`;
const USER1_EMAIL = process.env.USER1_EMAIL || '';
const USER1_PASSWORD = process.env.USER1_PASSWORD || '';
const USER2_EMAIL = process.env.USER2_EMAIL || '';
const USER2_PASSWORD = process.env.USER2_PASSWORD || '';

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

function assertEnvCredentials() {
  const missing = [];
  if (!USER1_EMAIL) missing.push('USER1_EMAIL');
  if (!USER1_PASSWORD) missing.push('USER1_PASSWORD');
  if (!USER2_EMAIL) missing.push('USER2_EMAIL');
  if (!USER2_PASSWORD) missing.push('USER2_PASSWORD');
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

function logStep(label, payload) {
  console.log(`\n[${label}]`);
  if (payload !== undefined) {
    console.log(typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2));
  }
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

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForEmailEvent(conversationId, recipientUserId) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const snap = await db.collection('email_events').orderBy('occurred_at', 'desc').limit(20).get();
    const match = snap.docs.find((doc) => {
      const data = doc.data() || {};
      return String(data.source_id || '') === conversationId &&
        String(data.recipient_user_id || '') === recipientUserId &&
        String(data.event_name || '').startsWith('message.created');
    });
    if (match) {
      return {
        id: match.id,
        ...match.data(),
      };
    }
    await sleep(1000);
  }
  return null;
}

async function main() {
  assertEnvCredentials();

  const [senderSession, ownerSession] = await Promise.all([
    signInWithPassword(USER1_EMAIL, USER1_PASSWORD),
    signInWithPassword(USER2_EMAIL, USER2_PASSWORD),
  ]);

  const [senderUser, ownerUser] = await Promise.all([
    admin.auth().getUserByEmail(USER1_EMAIL),
    admin.auth().getUserByEmail(USER2_EMAIL),
  ]);

  const offerTitle = `SMOKE messaging ${Date.now()}`;
  const offerRef = db.collection('offers').doc();
  const ownerDocRef = db.collection('users').doc(ownerUser.uid);
  const senderDocRef = db.collection('users').doc(senderUser.uid);
  const cleanupRefs = [];

  const ownerDoc = await ownerDocRef.get();
  const senderDoc = await senderDocRef.get();

  logStep('userDocs', {
    ownerUserDocExists: ownerDoc.exists,
    senderUserDocExists: senderDoc.exists,
  });

  await offerRef.set({
    title: offerTitle,
    description: 'Offre temporaire de smoke test messagerie',
    userId: ownerUser.uid,
    ownerId: ownerUser.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'active',
    isActive: true,
    city: 'Paris',
    postalCode: '75001',
  });
  cleanupRefs.push({ type: 'offer', ref: offerRef });

  logStep('scenario', {
    offerId: offerRef.id,
    offerTitle,
    ownerUid: ownerUser.uid,
    senderUid: senderUser.uid,
    ownerEmail: ownerUser.email || null,
    senderEmail: senderUser.email || null,
  });

  let conversationRef;

  try {
    const ensured = await callCallable('ensureOfferConversation', senderSession.idToken, {
      offerId: offerRef.id,
      offerTitle,
      otherUserId: ownerUser.uid,
    });
    logStep('ensureOfferConversation', ensured);

    const conversationId = String(ensured.conversationId || '').trim();
    if (!conversationId) {
      throw new Error('Conversation ID missing from ensureOfferConversation result');
    }
    conversationRef = db.collection('conversations').doc(conversationId);
    cleanupRefs.push({ type: 'conversation', ref: conversationRef });

    const ensuredAgain = await callCallable('ensureOfferConversation', senderSession.idToken, {
      offerId: offerRef.id,
      offerTitle,
      otherUserId: ownerUser.uid,
    });
    if (String(ensuredAgain.conversationId || '') !== conversationId) {
      throw new Error('ensureOfferConversation is not idempotent');
    }
    logStep('ensureOfferConversationAgain', ensuredAgain);

    const messageText = `smoke-${Date.now()}`;
    const sent = await callCallable('sendConversationMessage', senderSession.idToken, {
      conversationId,
      text: messageText,
    });
    logStep('sendConversationMessage', sent);

    const conversationAfterSend = (await conversationRef.get()).data() || {};
    logStep('conversationAfterSend', {
      lastMessage: conversationAfterSend.lastMessage || null,
      lastSenderId: conversationAfterSend.lastSenderId || null,
      unreadCount: conversationAfterSend.unreadCount || null,
    });

    const emailEvent = await waitForEmailEvent(conversationId, ownerUser.uid);
    logStep('messageEmailEvent', emailEvent ? {
      id: emailEvent.id,
      event_name: emailEvent.event_name,
      recipient_user_id: emailEvent.recipient_user_id,
      source_id: emailEvent.source_id,
    } : 'No email event observed in polling window');

    await callCallable('markConversationRead', ownerSession.idToken, {
      conversationId,
    });
    const conversationAfterRead = (await conversationRef.get()).data() || {};
    logStep('conversationAfterRead', {
      unreadCount: conversationAfterRead.unreadCount || null,
      lastReadAt: conversationAfterRead.lastReadAt || null,
    });

    const messagesSnap = await conversationRef
      .collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(3)
      .get();
    const messages = messagesSnap.docs.map((doc) => ({
      id: doc.id,
      text: doc.data().text || null,
      senderId: doc.data().senderId || null,
    }));
    logStep('recentMessages', messages);

    const ownerUnreadAfterSend = Number((conversationAfterSend.unreadCount || {})[ownerUser.uid] || 0);
    const ownerUnreadAfterRead = Number((conversationAfterRead.unreadCount || {})[ownerUser.uid] || 0);
    const senderUnread = Number((conversationAfterRead.unreadCount || {})[senderUser.uid] || 0);
    const latestMessage = messages[0];

    if (latestMessage?.text !== messageText) {
      throw new Error('Latest message text mismatch after send');
    }
    if (ownerUnreadAfterSend < 1) {
      throw new Error(`Owner unread count expected >= 1 after send, got ${ownerUnreadAfterSend}`);
    }
    if (ownerUnreadAfterRead !== 0) {
      throw new Error(`Owner unread count expected 0 after read, got ${ownerUnreadAfterRead}`);
    }
    if (senderUnread !== 0) {
      throw new Error(`Sender unread count expected 0, got ${senderUnread}`);
    }

    logStep('result', 'Messaging smoke test passed with the requested accounts.');
  } finally {
    for (const entry of cleanupRefs.reverse()) {
      try {
        if (entry.type === 'conversation') {
          await db.recursiveDelete(entry.ref);
        } else {
          await entry.ref.delete();
        }
      } catch (cleanupError) {
        logStep('cleanupWarning', `${entry.type} cleanup failed: ${cleanupError.message || cleanupError}`);
      }
    }
  }
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});