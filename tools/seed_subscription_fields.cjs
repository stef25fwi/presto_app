#!/usr/bin/env node

const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const APPLY = process.argv.includes('--apply');
const UID_ARG = process.argv.find((arg) => arg.startsWith('--uid='));
const LIMIT_ARG = process.argv.find((arg) => arg.startsWith('--limit='));
const ONLY_MISSING = !process.argv.includes('--include-complete');
const TARGET_UID = (UID_ARG || '').split('=')[1] || '';
const LIMIT = Math.max(
  1,
  Math.min(500, Number.parseInt((LIMIT_ARG || '--limit=100').split('=')[1], 10) || 100),
);

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function normalizeString(value) {
  return String(value ?? '').trim();
}

function isProfessionalAccount(data) {
  const accountType = normalizeString(data.accountType).toLowerCase();
  return accountType === 'professionnel' || accountType === 'pro';
}

function hasBooleanTrue(data, keys) {
  return keys.some((key) => data[key] === true);
}

function buildPatch(data) {
  const patch = {};

  if (!normalizeString(data.subscriptionPlan)) {
    patch.subscriptionPlan = 'free';
  }
  if (!normalizeString(data.subscriptionStatus)) {
    patch.subscriptionStatus = 'inactive';
  }
  if (!Object.prototype.hasOwnProperty.call(data, 'subscriptionExpiresAt')) {
    patch.subscriptionExpiresAt = null;
  }
  if (!Object.prototype.hasOwnProperty.call(data, 'phoneVerified')) {
    patch.phoneVerified = hasBooleanTrue(data, [
      'isPhoneVerified',
      'phoneNumberVerified',
    ]);
  }
  if (!Object.prototype.hasOwnProperty.call(data, 'proVerified')) {
    patch.proVerified = hasBooleanTrue(data, ['siretVerified', 'isProVerified']) || isProfessionalAccount(data);
  }

  if (Object.keys(patch).length == 0) {
    return null;
  }

  patch.updatedAt = FieldValue.serverTimestamp();
  return patch;
}

async function listCandidateDocs() {
  if (TARGET_UID) {
    const doc = await db.collection('users').doc(TARGET_UID).get();
    return doc.exists ? [doc] : [];
  }

  const snapshot = await db.collection('users').limit(LIMIT).get();
  return snapshot.docs;
}

async function main() {
  const docs = await listCandidateDocs();
  const plans = [];

  for (const doc of docs) {
    const data = doc.data() || {};
    const patch = buildPatch(data);

    if (ONLY_MISSING && patch == null) {
      continue;
    }

    plans.push({
      ref: doc.ref,
      uid: doc.id,
      email: normalizeString(data.email) || null,
      accountType: normalizeString(data.accountType) || null,
      patch,
    });
  }

  console.log(APPLY ? '🔴 MIGRATION RÉELLE (--apply)' : '🟢 DRY-RUN (aucune écriture)');
  console.log(`Projet             : ${PROJECT_ID}`);
  console.log(`Limite analysée    : ${TARGET_UID ? 1 : LIMIT}`);
  console.log(`UID ciblé          : ${TARGET_UID || 'aucun'}`);
  console.log(`Mode missing-only  : ${ONLY_MISSING ? 'oui' : 'non'}`);
  console.log(`Documents retenus  : ${plans.length}`);

  for (const plan of plans) {
    console.log(
      JSON.stringify(
        {
          uid: plan.uid,
          email: plan.email,
          accountType: plan.accountType,
          patch: plan.patch,
        },
        null,
        2,
      ),
    );
  }

  if (!APPLY) {
    console.log('\nDry run terminé. Relance avec --apply pour écrire uniquement les champs manquants.');
    return;
  }

  if (plans.length === 0) {
    console.log('Aucun document à mettre à jour.');
    return;
  }

  let batch = db.batch();
  let pending = 0;
  let applied = 0;

  for (const plan of plans) {
    if (!plan.patch) {
      continue;
    }

    batch.set(plan.ref, plan.patch, { merge: true });
    pending += 1;
    applied += 1;

    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  if (pending > 0) {
    await batch.commit();
  }

  console.log(`Migration appliquée sur ${applied} document(s).`);
}

main().catch((error) => {
  console.error('Erreur lors de l\'initialisation des champs abonnement.');
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});