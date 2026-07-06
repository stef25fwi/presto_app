#!/usr/bin/env node
/**
 * Audite ou supprime les comptes Firebase Auth correspondant aux anciens
 * enregistrements users classés test_or_seed dans un export d'audit.
 *
 * SÉCURITÉ : dry-run par défaut. Ajoute --apply pour supprimer réellement.
 *
 * Usage :
 *   node tools/manage_test_seed_auth.cjs
 *   node tools/manage_test_seed_auth.cjs --source=audit_logs/users_audit_export_20260706.json
 *   node tools/manage_test_seed_auth.cjs --uid=team_ilipresto_demo
 *   node tools/manage_test_seed_auth.cjs --apply
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

const APPLY = process.argv.includes('--apply');
const UID_ARG = process.argv.find((arg) => arg.startsWith('--uid='));
const SOURCE_ARG = process.argv.find((arg) => arg.startsWith('--source='));
const TARGET_UID = (UID_ARG || '').split('=')[1] || '';
const SOURCE_PATH = SOURCE_ARG
  ? SOURCE_ARG.split('=')[1]
  : 'audit_logs/users_audit_export_20260706.json';
const PROJECT_ID = 'presto-app-74abe';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const auth = admin.auth();

function loadSourceRecords() {
  const absolutePath = path.isAbsolute(SOURCE_PATH)
      ? SOURCE_PATH
      : path.join(process.cwd(), SOURCE_PATH);
  const payload = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
  const records = Array.isArray(payload.records) ? payload.records : [];
  const filtered = records.filter((row) => row.class === 'test_or_seed');
  if (TARGET_UID) {
    return filtered.filter((row) => row.uid === TARGET_UID);
  }
  return filtered;
}

async function inspectAuthRecord(row) {
  try {
    const user = await auth.getUser(row.uid);
    return {
      uid: row.uid,
      sourceEmail: row.email ?? null,
      authFound: true,
      authEmail: user.email ?? null,
      disabled: user.disabled,
      creationTime: user.metadata.creationTime ?? null,
      lastSignInTime: user.metadata.lastSignInTime ?? null,
    };
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      return {
        uid: row.uid,
        sourceEmail: row.email ?? null,
        authFound: false,
        authEmail: null,
        disabled: null,
        creationTime: null,
        lastSignInTime: null,
      };
    }
    throw error;
  }
}

async function deleteAuthRecord(uid) {
  try {
    await auth.deleteUser(uid);
    return { uid, deleted: true, message: 'Compte Auth supprimé' };
  } catch (error) {
    if (error?.code === 'auth/user-not-found') {
      return { uid, deleted: false, message: 'Compte Auth déjà absent' };
    }
    throw error;
  }
}

async function main() {
  console.log('==================================================');
  console.log(APPLY ? '🔴 SUPPRESSION AUTH RÉELLE (--apply)' : '🟢 DRY-RUN AUTH (aucune écriture)');
  console.log('==================================================');

  const sourceRows = loadSourceRecords();
  const inspected = [];

  for (const row of sourceRows) {
    inspected.push(await inspectAuthRecord(row));
  }

  const found = inspected.filter((row) => row.authFound);
  const missing = inspected.filter((row) => !row.authFound);

  console.log(`Source export       : ${SOURCE_PATH}`);
  console.log(`UID ciblé           : ${TARGET_UID || 'aucun'}`);
  console.log(`Test/seed sources   : ${sourceRows.length}`);
  console.log(`Comptes Auth trouvés: ${found.length}`);
  console.log(`Comptes déjà absents: ${missing.length}`);
  console.log(JSON.stringify(inspected, null, 2));

  if (!APPLY) {
    console.log('\nDry run terminé. Relance avec --apply pour supprimer les comptes Auth trouvés.');
    return;
  }

  const deletions = [];
  for (const row of found) {
    deletions.push(await deleteAuthRecord(row.uid));
  }

  console.log(JSON.stringify(deletions, null, 2));
  console.log(`Suppression Auth appliquée sur ${deletions.filter((row) => row.deleted).length} compte(s).`);
}

main().catch((error) => {
  console.error('Erreur lors de la gestion des comptes Auth test_or_seed.');
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});