const admin = require('../functions/node_modules/firebase-admin');
const {
  buildConversationMirrorFields,
  readConversationMirrorData,
} = require('../functions/lib/modules/messaging/mirror.js');
const {
  refreshUnreadMessageCount,
} = require('../functions/lib/modules/notifications/counters.js');

const PROJECT_ID = 'presto-app-74abe';
const CONVERSATION_ID = (process.env.CONVERSATION_ID || '').trim();
const SENDER_ID = (process.env.SENDER_ID || '').trim();
const DEFAULT_TEXT =
  process.env.MESSAGE_TEXT ||
  'Bonjour, je vous recontacte au sujet de votre annonce.';

if (!CONVERSATION_ID || !SENDER_ID) {
  throw new Error(
    'Missing target identifiers. Set CONVERSATION_ID and SENDER_ID before running this tool.',
  );
}

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

async function main() {
  const text = normalizeString(process.argv[2]) || DEFAULT_TEXT;
  const convRef = db.collection('conversations').doc(CONVERSATION_ID);

  const senderAuth = await admin.auth().getUser(SENDER_ID);
  const senderDoc = await db.collection('users').doc(SENDER_ID).get();
  const senderName = normalizeString(
    senderDoc.data()?.displayName ||
    senderDoc.data()?.display_name ||
    senderAuth.displayName ||
    senderAuth.email ||
    'Utilisateur',
  );

  let participantsToRefresh = [];
  let createdMessageId = '';

  await db.runTransaction(async (transaction) => {
    const convSnap = await transaction.get(convRef);
    if (!convSnap.exists) {
      throw new Error(`Conversation not found: ${CONVERSATION_ID}`);
    }

    const raw = convSnap.data() || {};
    const conversation = readConversationMirrorData(raw);
    const participants = conversation.participants;
    if (!participants.includes(SENDER_ID)) {
      throw new Error(
        `Configured sender is not a participant of the configured conversation`,
      );
    }

    const messageRef = convRef.collection('messages').doc();
    createdMessageId = messageRef.id;
    const isFirstMessage = Number(conversation.messageCount || 0) <= 0;

    transaction.set(messageRef, {
      text,
      body: text,
      senderId: SENDER_ID,
      sender_id: SENDER_ID,
      senderName,
      sender_name: senderName,
      isFirstMessage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const archivedBy = { ...conversation.archivedBy };
    const unreadCount = { ...conversation.unreadCount };

    for (const participantId of participants) {
      archivedBy[participantId] = false;
      const currentUnread = Number(unreadCount[participantId] || 0);
      unreadCount[participantId] =
        participantId === SENDER_ID ? 0 : currentUnread + 1;
    }

    transaction.set(
      convRef,
      buildConversationMirrorFields({
        ...conversation,
        participants,
        participantNames: {
          ...conversation.participantNames,
          [SENDER_ID]: senderName,
        },
        archivedBy,
        unreadCount,
        lastMessage: text,
        lastSenderId: SENDER_ID,
        lastSenderName: senderName,
        status: 'open',
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: Number(conversation.messageCount || 0) + 1,
      }),
      { merge: true },
    );

    participantsToRefresh = participants;
  });

  await Promise.all(
    participantsToRefresh.map((participantId) =>
      refreshUnreadMessageCount(participantId),
    ),
  );

  const updatedSnap = await convRef.get();
  const updated = updatedSnap.data() || {};

  logStep('messageSent', {
    conversationId: CONVERSATION_ID,
    messageId: createdMessageId,
    senderId: SENDER_ID,
    senderName,
    text,
  });
  logStep('conversationAfterSend', {
    lastMessage: updated.lastMessage || updated.last_message || null,
    lastSenderId: updated.lastSenderId || updated.last_sender_id || null,
    unreadCount: updated.unreadCount || updated.unread_count || null,
    messageCount: updated.messageCount || updated.message_count || 0,
  });
}

main().catch((error) => {
  console.error('\n[error]');
  console.error(error && error.stack ? error.stack : error);
  process.exitCode = 1;
});