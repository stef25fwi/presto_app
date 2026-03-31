#!/usr/bin/env node

const admin = require('firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const APPLY = process.argv.includes('--apply');
const OWNER_ID = (process.env.OWNER_ID || '').trim();
const LIMIT_ARG = process.argv.find((arg) => arg.startsWith('--limit='));
const LIMIT = Math.max(
  1,
  Math.min(100, Number.parseInt((LIMIT_ARG || '--limit=20').split('=')[1], 10) || 20),
);

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

function normalizeString(value) {
  return String(value ?? '').trim();
}

function isReadyToPublish(data) {
  const status = normalizeString(data.status);
  const modStatus = normalizeString(data.moderationStatus);
  const mediaStatus = normalizeString(data.mediaProcessingStatus);
  if (status !== 'pending') return false;
  // Accept approved, auto_flagged, manual_review, or missing moderation status
  const acceptableMod = ['approved', 'auto_flagged', 'manual_review', ''];
  if (!acceptableMod.includes(modStatus)) return false;
  // Accept completed or missing media status
  if (mediaStatus !== '' && mediaStatus !== 'completed') return false;
  return true;
}

async function main() {
  let query = db.collection('listings')
    .where('status', '==', 'pending')
    .limit(LIMIT);

  if (OWNER_ID) {
    query = query.where('ownerId', '==', OWNER_ID);
  }

  const snapshot = await query.get();
  const readyDocs = snapshot.docs.filter((doc) => isReadyToPublish(doc.data() || {}));

  if (readyDocs.length === 0) {
    console.log('Aucune annonce approuvée/pending à publier.');
    return;
  }

  console.log(`Annonces prêtes à publier: ${readyDocs.length}`);
  for (const doc of readyDocs) {
    const data = doc.data() || {};
    console.log(JSON.stringify({
      id: doc.id,
      ownerId: normalizeString(data.ownerId),
      title: normalizeString(data.title),
      status: normalizeString(data.status),
      moderationStatus: normalizeString(data.moderationStatus),
      mediaProcessingStatus: normalizeString(data.mediaProcessingStatus),
      autoPublishAfter: data.autoPublishAfter ?? null,
    }, null, 2));
  }

  if (!APPLY) {
    console.log('\nDry run terminé. Relance avec --apply pour publier ces annonces.');
    return;
  }

  const batch = db.batch();
  for (const doc of readyDocs) {
    batch.set(doc.ref, {
      status: 'active',
      visibility: 'public',
      moderationStatus: 'approved',
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      autoPublishAfter: null,
    }, { merge: true });
  }

  await batch.commit();
  console.log(`Publication effectuée pour ${readyDocs.length} annonce(s).`);
}

main().catch((error) => {
  console.error('Erreur lors de la publication des annonces pending approuvées.');
  console.error(error);
  process.exitCode = 1;
});