#!/usr/bin/env node

const admin = require('firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const APPLY = process.argv.includes('--apply');
const OWNER_ID = (process.env.OWNER_ID || '').trim();
const COLLECTION_ARG = process.argv.find((arg) => arg.startsWith('--collection='));
const LIMIT_ARG = process.argv.find((arg) => arg.startsWith('--limit='));

const COLLECTION_MODE = ((COLLECTION_ARG || '--collection=both').split('=')[1] || 'both')
  .trim()
  .toLowerCase();

const LIMIT = Math.max(
  1,
  Math.min(5000, Number.parseInt((LIMIT_ARG || '--limit=500').split('=')[1], 10) || 500),
);

const VALID_COLLECTION_MODES = new Set(['listings', 'offers', 'both']);
if (!VALID_COLLECTION_MODES.has(COLLECTION_MODE)) {
  console.error('Valeur invalide pour --collection. Utiliser: listings, offers, both');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

function asString(value) {
  return String(value ?? '').trim();
}

function isPublicVisibility(value) {
  if (typeof value === 'string') {
    return value.trim().toLowerCase() === 'public';
  }
  if (value && typeof value === 'object') {
    return value.isPublic === true;
  }
  return false;
}

function isArchivedLike(status) {
  const s = asString(status).toLowerCase();
  return s === 'archived' || s === 'deleted' || s === 'removed' || s === 'sold';
}

function isPublicByContract(data) {
  const status = asString(data.status).toLowerCase();
  const isPublished = data.isPublished === true;
  const publicVisibility = isPublicVisibility(data.visibility);

  if (isArchivedLike(status)) return false;
  if (status === 'published') return true;
  if (status === 'active' && publicVisibility) return true;
  if (isPublished) return true;
  return false;
}

function buildPatch(data) {
  const status = asString(data.status).toLowerCase();
  const publicVisibility = isPublicVisibility(data.visibility);
  const isPublished = data.isPublished === true;

  const patch = {};

  // Canonical public visibility for all publicly readable listings.
  if (!publicVisibility || data.visibility !== 'public') {
    patch.visibility = 'public';
  }

  // Canonical status for legacy isPublished docs.
  if (status !== 'published' && status !== 'active' && isPublished) {
    patch.status = 'published';
  }

  return patch;
}

async function scanCollection(collectionName) {
  let query = db.collection(collectionName).limit(LIMIT);
  if (OWNER_ID) {
    query = query.where('ownerId', '==', OWNER_ID);
  }

  const snap = await query.get();
  const rows = [];

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!isPublicByContract(data)) continue;

    const patch = buildPatch(data);
    if (Object.keys(patch).length === 0) continue;

    rows.push({
      collection: collectionName,
      id: doc.id,
      before: {
        status: data.status ?? null,
        visibility: data.visibility ?? null,
        isPublished: data.isPublished ?? null,
      },
      patch,
    });
  }

  return { scanned: snap.size, updates: rows };
}

async function applyUpdates(updates) {
  if (updates.length === 0) return 0;

  let applied = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const update of updates) {
    const ref = db.collection(update.collection).doc(update.id);
    batch.set(
      ref,
      {
        ...update.patch,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    batchCount++;

    if (batchCount >= 400) {
      await batch.commit();
      applied += batchCount;
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    applied += batchCount;
  }

  return applied;
}

async function main() {
  const collections = COLLECTION_MODE === 'both' ? ['listings', 'offers'] : [COLLECTION_MODE];

  const reports = [];
  for (const collectionName of collections) {
    reports.push(await scanCollection(collectionName));
  }

  const updates = reports.flatMap((r) => r.updates);
  const byCollection = updates.reduce((acc, row) => {
    acc[row.collection] = (acc[row.collection] || 0) + 1;
    return acc;
  }, {});

  console.log(JSON.stringify({
    projectId: PROJECT_ID,
    mode: APPLY ? 'apply' : 'dry-run',
    collectionMode: COLLECTION_MODE,
    ownerIdFilter: OWNER_ID || null,
    limit: LIMIT,
    scanned: reports.reduce((sum, r) => sum + r.scanned, 0),
    candidates: updates.length,
    candidatesByCollection: byCollection,
  }, null, 2));

  if (updates.length > 0) {
    console.log('\nExemples de mutations (max 30):');
    for (const row of updates.slice(0, 30)) {
      console.log(JSON.stringify(row));
    }
  }

  if (!APPLY) {
    console.log('\nDry-run termine. Relancer avec --apply pour ecrire les changements.');
    return;
  }

  const applied = await applyUpdates(updates);
  console.log(`\nNormalisation appliquee: ${applied} document(s).`);
}

main().catch((error) => {
  console.error('Erreur pendant la normalisation des annonces publiques.');
  console.error(error);
  process.exitCode = 1;
});
