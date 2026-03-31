#!/usr/bin/env node
// Diagnostic : trouve TOUTES les annonces non-active et affiche leurs champs clés
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'presto-app-74abe' });
}
const db = admin.firestore();

function norm(val) { return String(val ?? '').trim(); }
function tsToISO(ts) {
  if (!ts) return null;
  if (typeof ts.toDate === 'function') return ts.toDate().toISOString();
  if (ts._seconds != null) return new Date(ts._seconds * 1000).toISOString();
  return String(ts);
}

async function main() {
  // 1. Chercher toutes les annonces pending (quel que soit moderationStatus)
  const pendingSnap = await db.collection('listings')
    .where('status', '==', 'pending')
    .limit(50)
    .get();

  // 2. Chercher aussi les annonces submitted / manual_review / rejected
  const allSnap = await db.collection('listings')
    .where('status', 'in', ['pending', 'submitted', 'draft', 'manual_review', 'rejected'])
    .limit(50)
    .get();

  // Fusionner sans doublon
  const seen = new Set();
  const docs = [];
  for (const snap of [pendingSnap, allSnap]) {
    for (const doc of snap.docs) {
      if (!seen.has(doc.id)) {
        seen.add(doc.id);
        docs.push(doc);
      }
    }
  }

  if (docs.length === 0) {
    console.log('Aucune annonce en attente trouvée.');
    
    // Vérifier les drafts non soumis
    const draftsV2 = await db.collection('listing_drafts_v2').limit(20).get();
    const draftsV1 = await db.collection('listing_drafts').limit(20).get();
    console.log(`\nDrafts v2: ${draftsV2.size}, Drafts v1: ${draftsV1.size}`);
    
    for (const doc of [...draftsV2.docs, ...draftsV1.docs]) {
      const d = doc.data();
      console.log(JSON.stringify({
        collection: doc.ref.parent.id,
        id: doc.id,
        status: norm(d.status),
        listingId: norm(d.listingId),
        title: norm(d.title).slice(0, 50),
        ownerId: norm(d.ownerId),
        createdAt: tsToISO(d.createdAt),
        updatedAt: tsToISO(d.updatedAt),
      }, null, 2));
    }
    return;
  }

  console.log(`\n📋 ${docs.length} annonce(s) non-active trouvée(s) :\n`);

  for (const doc of docs) {
    const d = doc.data();
    const apMs = d.autoPublishAfter?.toMillis?.() ?? 0;
    const nowMs = Date.now();
    const apDelta = apMs > 0 ? Math.round((apMs - nowMs) / 1000) : null;

    console.log('─'.repeat(60));
    console.log(`  ID                    : ${doc.id}`);
    console.log(`  Titre                 : ${norm(d.title)}`);
    console.log(`  Owner                 : ${norm(d.ownerId)}`);
    console.log(`  status                : ${norm(d.status)}`);
    console.log(`  moderationStatus      : ${norm(d.moderationStatus)}`);
    console.log(`  visibility            : ${norm(d.visibility)}`);
    console.log(`  mediaProcessingStatus : ${norm(d.mediaProcessingStatus)}`);
    console.log(`  autoPublishAfter      : ${tsToISO(d.autoPublishAfter)}${apDelta != null ? ` (${apDelta > 0 ? `dans ${apDelta}s` : `passé depuis ${-apDelta}s`})` : ''}`);
    console.log(`  publishedAt           : ${tsToISO(d.publishedAt)}`);
    console.log(`  createdAt             : ${tsToISO(d.createdAt)}`);
    console.log(`  updatedAt             : ${tsToISO(d.updatedAt)}`);
    console.log(`  riskScore             : ${d.riskScore ?? 'N/A'}`);
    console.log(`  media                 : ${Array.isArray(d.media) ? `${d.media.length} photo(s)` : 'aucune'}`);
    console.log(`  moderationReason      : ${norm(d.moderationReason) || 'N/A'}`);
    
    // Diagnostic
    const issues = [];
    if (norm(d.status) !== 'pending') issues.push(`status="${norm(d.status)}" au lieu de "pending"`);
    if (norm(d.moderationStatus) !== 'approved') issues.push(`moderationStatus="${norm(d.moderationStatus)}" → modération non validée`);
    if (norm(d.mediaProcessingStatus) !== 'completed') issues.push(`mediaProcessingStatus="${norm(d.mediaProcessingStatus)}" → photos pas finies`);
    if (apMs > nowMs) issues.push(`autoPublishAfter encore dans le futur (${apDelta}s)`);
    if (!d.autoPublishAfter && norm(d.moderationStatus) === 'approved') issues.push('autoPublishAfter absent → auto-publish ne se déclenchera jamais');
    
    if (issues.length > 0) {
      console.log(`\n  ⚠️  BLOCAGES DÉTECTÉS :`);
      for (const issue of issues) {
        console.log(`     → ${issue}`);
      }
    } else {
      console.log(`\n  ✅ Prête à être publiée par le scheduler.`);
    }
    console.log('');
  }
}

main().catch((err) => {
  console.error('Erreur :', err.message || err);
  process.exitCode = 1;
});
