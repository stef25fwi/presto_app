#!/usr/bin/env node
/**
 * Liste ou supprime les comptes users classés test_or_seed.
 *
 * SÉCURITÉ : dry-run par défaut.
 * --apply supprime le document Firestore users/{uid}.
 * --with-auth tente aussi de supprimer le compte Firebase Auth associé.
 *
 * Usage :
 *   node tools/manage_test_seed_users.cjs
 *   node tools/manage_test_seed_users.cjs --limit=25
 *   node tools/manage_test_seed_users.cjs --uid=team_ilipresto_demo
 *   node tools/manage_test_seed_users.cjs --apply --limit=25
 *   node tools/manage_test_seed_users.cjs --apply --with-auth --limit=25
 */

const fs = require('fs');
const path = require('path');
const admin = require(path.join(
  __dirname,
  '..',
  'functions',
  'node_modules',
  'firebase-admin',
));

const {
  classifyUserRecord,
  summarizeUserRecord,
} = require('./lib/user_record_classifier.cjs');

const APPLY = process.argv.includes('--apply');
const WITH_AUTH = process.argv.includes('--with-auth');
const UID_ARG = process.argv.find((arg) => arg.startsWith('--uid='));
const LIMIT_ARG = process.argv.find((arg) => arg.startsWith('--limit='));
const TARGET_UID = (UID_ARG || '').split('=')[1] || '';
const PROJECT_ID = 'presto-app-74abe';
const LIMIT = Math.max(
  1,
  Math.min(500, Number.parseInt((LIMIT_ARG || '--limit=100').split('=')[1], 10) || 100),
);
const KEY_PATH = path.join(__dirname, '..', 'sa-key.json');

if (fs.existsSync(KEY_PATH)) {
  admin.initializeApp({ credential: admin.credential.cert(KEY_PATH) });
} else {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const auth = admin.auth();

async function loadCandidates() {
  if (TARGET_UID) {
    const doc = await db.collection('users').doc(TARGET_UID).get();
    if (!doc.exists) return [];
    return classifyUserRecord(doc.id, doc.data() || {}) === 'test_or_seed'
        ? [doc]
        : [];
  }

  const snapshot = await db.collection('users').orderBy('__name__').limit(LIMIT).get();
  return snapshot.docs.filter(
    (doc) => classifyUserRecord(doc.id, doc.data() || {}) === 'test_or_seed',
  );
}

async function deleteAuthIfRequested(uid) {
  if (!WITH_AUTH) {
    return { attempted: false, deleted: false, message: 'Auth conservé' };
  }

  try {
    await auth.deleteUser(uid);
    return { attempted: true, deleted: true, message: 'Compte Auth supprimé' };
  } catch (error) {
    return {
      attempted: true,
      deleted: false,
      message: error?.code || error?.message || 'Suppression Auth échouée',
    };
  }
}

async function main() {
  console.log('==================================================');
  console.log(APPLY ? '🔴 SUPPRESSION RÉELLE (--apply)' : '🟢 DRY-RUN (aucune écriture)');
  console.log('==================================================');

  const docs = await loadCandidates();
  const authResults = [];

  console.log(`Limite analysée    : ${TARGET_UID ? 1 : LIMIT}`);
  console.log(`UID ciblé          : ${TARGET_UID || 'aucun'}`);
  console.log(`Suppression Auth   : ${WITH_AUTH ? 'oui' : 'non'}`);
  console.log(`Test/seed retenus  : ${docs.length}`);

  for (const doc of docs) {
    console.log(JSON.stringify(summarizeUserRecord(doc.id, doc.data() || {}), null, 2));
  }

  if (!APPLY) {
    console.log('\nDry run terminé. Relance avec --apply pour supprimer les docs users test_or_seed.');
    if (!WITH_AUTH) {
      console.log('Ajoute --with-auth uniquement si tu veux aussi supprimer les comptes Firebase Auth associés.');
    }
    return;
  }

  for (const doc of docs) {
    await db.recursiveDelete(doc.ref);
    authResults.push({ uid: doc.id, ...(await deleteAuthIfRequested(doc.id)) });
  }

  console.log(`Suppression appliquée sur ${docs.length} document(s) users test_or_seed.`);
  if (WITH_AUTH) {
    console.log(JSON.stringify(authResults, null, 2));
  }
}

main().catch((error) => {
  console.error('Erreur lors de la gestion des comptes test_or_seed.');
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});