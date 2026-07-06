const admin = require('../functions/node_modules/firebase-admin');

const FIREBASE_WEB_API_KEY = process.env.FIREBASE_WEB_API_KEY || '';
const PROJECT_ID = 'presto-app-74abe';
const FUNCTIONS_REGION = process.env.FUNCTIONS_REGION || 'europe-west1';
const CALLABLE_BASE_URL = `https://${FUNCTIONS_REGION}-${PROJECT_ID}.cloudfunctions.net`;
const BUYER_EMAIL = process.env.TEST_BUYER_EMAIL || 'messaging.moderation.buyer@ilipresto.test';
const BUYER_PASSWORD = process.env.TEST_BUYER_PASSWORD || 'TestPass!123456';
const SELLER_EMAIL = process.env.TEST_SELLER_EMAIL || 'messaging.moderation.seller@ilipresto.test';
const SELLER_PASSWORD = process.env.TEST_SELLER_PASSWORD || 'TestPass!123456';
const SEED_TAG = `messaging-moderation-smoke-${Date.now()}`;

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

function assertRequiredEnv() {
  if (!FIREBASE_WEB_API_KEY) {
    throw new Error('Missing required environment variable: FIREBASE_WEB_API_KEY');
  }
}

function logStep(label, payload) {
  console.log(`\n[${label}]`);
  if (payload !== undefined) {
    console.log(typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2));
  }
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function signInWithPassword(email, password) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}`,
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
    const error = new Error(`${name} failed: ${response.status} ${JSON.stringify(payload)}`);
    error.payload = payload;
    throw error;
  }

  return payload.result;
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
  }, { merge: true });
}

async function setMessagingMode(mode) {
  await db.collection('appConfig').doc('marketplace').set({
    moderation: {
      messagingMode: mode,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: 'copilot-smoke-test',
  }, { merge: true });
}

async function createOffer({ sellerUser, title }) {
  const ref = db.collection('offers').doc();
  await ref.set({
    title,
    description: 'Annonce de test créée pour le smoke test de modération messagerie.',
    advertiserName: sellerUser.displayName || 'Annonceur test',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return ref;
}

async function createConversation({ buyerSession, buyerUser, sellerUser, label }) {
  const offerRef = await createOffer({
    sellerUser,
    title: `Smoke moderation ${label} ${new Date().toISOString()}`,
  });

  const ensureResult = await callCallable('ensureOfferConversation', buyerSession.idToken, {
    offerId: offerRef.id,
    offerTitle: `Smoke moderation ${label}`,
    otherUserId: sellerUser.uid,
    currentUserName: buyerUser.displayName,
    otherUserName: sellerUser.displayName,
  });
  const conversationId = String(ensureResult.conversationId || '').trim();
  if (!conversationId) {
    throw new Error(`Conversation ID missing for ${label}`);
  }

  return {
    offerRef,
    conversationRef: db.collection('conversations').doc(conversationId),
    conversationId,
  };
}

async function waitForModerationMessage(conversationRef, messageId) {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const snap = await conversationRef.collection('messages').doc(messageId).get();
    const data = snap.data() || {};
    const moderation = data.moderation || {};
    const status = String(moderation.status || '').trim().toLowerCase();
    if (status && status !== 'pending') {
      return {
        id: snap.id,
        ...data,
      };
    }
    await sleep(1000);
  }
  throw new Error(`Timed out while waiting for moderation resolution on message ${messageId}`);
}

async function main() {
  assertRequiredEnv();

  const originalMarketplaceSnap = await db.collection('appConfig').doc('marketplace').get();
  const originalModeration = (originalMarketplaceSnap.data()?.moderation ?? {});
  const originalMode = String(originalModeration.messagingMode || 'hybrid').trim() || 'hybrid';

  const buyerRecord = await upsertAuthUser({
    email: BUYER_EMAIL,
    password: BUYER_PASSWORD,
    displayName: 'Acheteur Moderation Smoke',
  });
  const sellerRecord = await upsertAuthUser({
    email: SELLER_EMAIL,
    password: SELLER_PASSWORD,
    displayName: 'Vendeur Moderation Smoke',
  });

  await Promise.all([
    upsertUserDoc(buyerRecord, 'Acheteur Moderation Smoke'),
    upsertUserDoc(sellerRecord, 'Vendeur Moderation Smoke'),
  ]);

  const [buyerSession] = await Promise.all([
    signInWithPassword(BUYER_EMAIL, BUYER_PASSWORD),
  ]);

  const cleanupRefs = [];

  try {
    await setMessagingMode('hybrid');
    const hybridScenario = await createConversation({
      buyerSession,
      buyerUser: buyerRecord,
      sellerUser: sellerRecord,
      label: 'hybrid',
    });
    cleanupRefs.push(hybridScenario.offerRef, hybridScenario.conversationRef);

    const hybridSend = await callCallable('sendConversationMessage', buyerSession.idToken, {
      conversationId: hybridScenario.conversationId,
      text: 'Contactez-moi sur telegram https://example.com !!! urgent cash',
    });
    const hybridMessage = await waitForModerationMessage(
      hybridScenario.conversationRef,
      String(hybridSend.messageId || ''),
    );
    const hybridModeration = hybridMessage.moderation || {};
    if (String(hybridModeration.status || '') !== 'manual_review') {
      throw new Error(`Hybrid mode expected manual_review, got ${JSON.stringify(hybridModeration)}`);
    }
    logStep('hybrid', hybridModeration);

    await setMessagingMode('hidden_until_validated');
    const strictScenario = await createConversation({
      buyerSession,
      buyerUser: buyerRecord,
      sellerUser: sellerRecord,
      label: 'strict',
    });
    cleanupRefs.push(strictScenario.offerRef, strictScenario.conversationRef);

    let strictBlocked = false;
    try {
      await callCallable('sendConversationMessage', buyerSession.idToken, {
        conversationId: strictScenario.conversationId,
        text: 'Message interdit escort',
      });
    } catch (error) {
      strictBlocked = String(error.message || '').includes('messaging_text_blocked') ||
        String(error.message || '').includes('messaging_content_review_required');
      if (!strictBlocked) {
        throw error;
      }
    }
    if (!strictBlocked) {
      throw new Error('Strict mode expected synchronous blocking but the message was accepted.');
    }
    logStep('strict', 'Blocked synchronously as expected');

    await setMessagingMode('visible_then_retract');
    const retractScenario = await createConversation({
      buyerSession,
      buyerUser: buyerRecord,
      sellerUser: sellerRecord,
      label: 'visible_then_retract',
    });
    cleanupRefs.push(retractScenario.offerRef, retractScenario.conversationRef);

    const retractSend = await callCallable('sendConversationMessage', buyerSession.idToken, {
      conversationId: retractScenario.conversationId,
      text: 'Message interdit escort',
    });
    const retractMessage = await waitForModerationMessage(
      retractScenario.conversationRef,
      String(retractSend.messageId || ''),
    );
    const retractModeration = retractMessage.moderation || {};
    if (String(retractModeration.status || '') !== 'rejected') {
      throw new Error(`Visible-then-retract mode expected rejected, got ${JSON.stringify(retractModeration)}`);
    }
    logStep('visible_then_retract', retractModeration);

    logStep('result', 'Messaging moderation smoke test passed for hybrid, strict and visible_then_retract.');
  } finally {
    await setMessagingMode(originalMode);
    for (const ref of cleanupRefs.reverse()) {
      try {
        if (ref.path.startsWith('conversations/')) {
          await db.recursiveDelete(ref);
        } else {
          await ref.delete();
        }
      } catch (error) {
        logStep('cleanupWarning', String(error.message || error));
      }
    }
  }
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});