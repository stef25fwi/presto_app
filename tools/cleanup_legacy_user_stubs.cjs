#!/usr/bin/env node
/**
 * Nettoie les documents users legacy_stub.
 *
 * Critères legacy_stub : UID non canonique + pas d'email + pas de createdAt
 * + pas de champs profil hydratés.
 *
 * SÉCURITÉ : dry-run par défaut. Ajoute --apply pour supprimer réellement.
 *
 * Usage :
 *   node tools/cleanup_legacy_user_stubs.cjs
 *   node tools/cleanup_legacy_user_stubs.cjs --limit=25
 *   node tools/cleanup_legacy_user_stubs.cjs --uid=A
 *   node tools/cleanup_legacy_user_stubs.cjs --apply --limit=25
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

async function loadCandidates() {
  if (TARGET_UID) {
    const doc = await db.collection('users').doc(TARGET_UID).get();
    if (!doc.exists) return [];
    return classifyUserRecord(doc.id, doc.data() || {}) === 'legacy_stub'
        ? [doc]
        : [];
  }

  const snapshot = await db.collection('users').orderBy('__name__').limit(LIMIT).get();
  return snapshot.docs.filter(
    (doc) => classifyUserRecord(doc.id, doc.data() || {}) === 'legacy_stub',
  );
}

async function main() {
  console.log('==================================================');
  console.log(APPLY ? '🔴 NETTOYAGE RÉEL (--apply)' : '🟢 DRY-RUN (aucune écriture)');
  console.log('==================================================');

  const docs = await loadCandidates();

  console.log(`Limite analysée    : ${TARGET_UID ? 1 : LIMIT}`);
  console.log(`UID ciblé          : ${TARGET_UID || 'aucun'}`);
  console.log(`Legacy stubs retenus : ${docs.length}`);

  for (const doc of docs) {
    console.log(JSON.stringify(summarizeUserRecord(doc.id, doc.data() || {}), null, 2));
  }

  if (!APPLY) {
    console.log('\nDry run terminé. Relance avec --apply pour supprimer ces documents users legacy_stub.');
    return;
  }

  for (const doc of docs) {
    await db.recursiveDelete(doc.ref);
  }

  console.log(`Nettoyage appliqué sur ${docs.length} document(s) users legacy_stub.`);
}

main().catch((error) => {
  console.error('Erreur lors du nettoyage des legacy_stub.');
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});