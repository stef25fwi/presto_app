const fs = require('fs');
const path = require('path');

const email = (process.argv[2] || '').trim().toLowerCase();
if (!email) {
  console.error('Usage: node scripts/audit_messaging_profile.js email@example.com');
  process.exit(1);
}

function loadAdmin() {
  const candidates = [
    path.join(process.cwd(), 'functions/node_modules/firebase-admin'),
    'firebase-admin',
  ];
  for (const c of candidates) {
    try { return require(c); } catch (_) {}
  }
  throw new Error('firebase-admin introuvable. Lance: npm --prefix functions install');
}

function ts(v) {
  if (!v) return '';
  if (typeof v.toDate === 'function') return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  return String(v);
}

function pick(data, keys) {
  for (const k of keys) {
    const v = data?.[k];
    if (v !== undefined && v !== null && String(v).trim() !== '') return v;
  }
  return '';
}

async function safeQuery(label, query) {
  try {
    const snap = await query.get();
    return snap.docs;
  } catch (e) {
    console.log(`⚠️ Query ignorée ${label}: ${e.code || e.message}`);
    return [];
  }
}

async function main() {
  const admin = loadAdmin();
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();

  console.log('============================================================');
  console.log('AUDIT MESSAGERIE PROFIL');
  console.log('Email cible:', email);
  console.log('Date:', new Date().toISOString());
  console.log('============================================================\n');

  const userDocs = new Map();

  for (const field of ['email', 'emailLower', 'normalizedEmail']) {
    const docs = await safeQuery(`users.${field}`, db.collection('users').where(field, '==', email));
    for (const d of docs) userDocs.set(d.id, d);
  }

  if (userDocs.size === 0) {
    console.log('❌ Aucun document users trouvé pour cet email.');
    console.log('À vérifier: champ email absent, email différent, ou profil non créé.');
    return;
  }

  console.log(`✅ Utilisateur(s) trouvé(s): ${userDocs.size}\n`);

  for (const [uid, doc] of userDocs.entries()) {
    const data = doc.data() || {};
    console.log('------------------------------------------------------------');
    console.log('USER DOC');
    console.log('uid:', uid);
    console.log('email:', pick(data, ['email', 'emailLower', 'normalizedEmail']));
    console.log('displayName:', pick(data, ['displayName', 'pseudo', 'name', 'fullName']));
    console.log('phone:', pick(data, ['phone', 'phoneNumber', 'telephone']));
    console.log('photo:', pick(data, ['photoUrl', 'photoURL', 'profilePhotoUrl', 'avatarUrl']));
    console.log('profileCompleted:', data.profileCompleted);
    console.log('disabled:', data.disabled);
    console.log('roles:', JSON.stringify(data.roles || data.role || data.primaryRole || ''));
    console.log('createdAt:', ts(data.createdAt));
    console.log('updatedAt:', ts(data.updatedAt));
    console.log('');

    const convs = new Map();
    const convRef = db.collection('conversations');

    const arrayFields = ['participantIds', 'participants', 'participant_ids', 'userIds', 'memberIds'];
    for (const f of arrayFields) {
      const docs = await safeQuery(`conversations.${f} array-contains uid`, convRef.where(f, 'array-contains', uid));
      for (const d of docs) convs.set(d.id, d);
    }

    const directFields = [
      'userId', 'uid', 'ownerId', 'createdBy',
      'buyerId', 'buyer_id', 'sellerId', 'seller_id',
      'clientId', 'client_id', 'providerId', 'provider_id',
      'senderId', 'recipientId', 'receiverId'
    ];
    for (const f of directFields) {
      const docs = await safeQuery(`conversations.${f} == uid`, convRef.where(f, '==', uid));
      for (const d of docs) convs.set(d.id, d);
    }

    console.log(`CONVERSATIONS TROUVÉES: ${convs.size}\n`);

    if (convs.size === 0) {
      console.log('⚠️ Aucune conversation trouvée pour ce UID.');
      console.log('Causes possibles: mauvais uid, champs participants non standard, conversation supprimée/archivée, ou collection différente.\n');
      continue;
    }

    let index = 0;
    for (const [convId, convDoc] of convs.entries()) {
      index++;
      const c = convDoc.data() || {};
      console.log(`--- Conversation ${index}/${convs.size}: ${convId}`);
      console.log('participants:', JSON.stringify(pick(c, ['participantIds', 'participants', 'participant_ids', 'userIds', 'memberIds'])));
      console.log('offerId:', pick(c, ['offerId', 'listingId', 'listing_id']));
      console.log('lastMessage:', String(pick(c, ['lastMessage', 'last_message', 'preview'])).slice(0, 180));
      console.log('createdAt:', ts(c.createdAt));
      console.log('updatedAt:', ts(c.updatedAt));
      console.log('lastMessageAt:', ts(pick(c, ['lastMessageAt', 'last_message_at'])));
      console.log('blocked fields:', JSON.stringify({
        blocked: c.blocked,
        isBlocked: c.isBlocked,
        blockedBy: c.blockedBy,
        blockedByUid: c.blockedByUid,
        deletedFor: c.deletedFor,
        archivedFor: c.archivedFor,
        hiddenFor: c.hiddenFor,
      }));

      const msgRef = convDoc.ref.collection('messages');
      let count = 'inconnu';
      try {
        const countSnap = await msgRef.count().get();
        count = countSnap.data().count;
      } catch (_) {}

      console.log('messages count:', count);

      const lastMsgs = await safeQuery(
        `messages subcollection ${convId}`,
        msgRef.orderBy('createdAt', 'desc').limit(5)
      );

      if (lastMsgs.length === 0) {
        console.log('⚠️ Aucun message dans conversations/{id}/messages ou ordre createdAt absent.');
      } else {
        for (const m of lastMsgs.reverse()) {
          const md = m.data() || {};
          const text = String(pick(md, ['text', 'message', 'body', 'content'])).replace(/\s+/g, ' ').slice(0, 160);
          console.log(`  msg ${m.id}`);
          console.log('   sender:', pick(md, ['senderId', 'sender_id', 'uid', 'fromUid']));
          console.log('   createdAt:', ts(md.createdAt));
          console.log('   read:', JSON.stringify(pick(md, ['read', 'readBy', 'seenBy'])));
          console.log('   text:', text);
          console.log('   attachments:', JSON.stringify(pick(md, ['attachments', 'files', 'imageUrl', 'attachmentUrl'])));
        }
      }

      console.log('');
    }
  }
}

main().catch((e) => {
  console.error('❌ Audit live Firestore impossible:', e.code || e.message || e);
  console.error('Vérifie GOOGLE_APPLICATION_CREDENTIALS ou les droits Admin SDK.');
  process.exit(2);
});
