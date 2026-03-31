#!/usr/bin/env node
// Approuve manuellement une annonce auto_flagged et la publie
// Usage: node tools/approve_flagged_listing.cjs <LISTING_ID> [--apply]

const admin = require('firebase-admin');
const LISTING_ID = process.argv[2];
const APPLY = process.argv.includes('--apply');

if (!LISTING_ID || LISTING_ID.startsWith('--')) {
  console.error('Usage: node tools/approve_flagged_listing.cjs <LISTING_ID> [--apply]');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'presto-app-74abe' });
}
const db = admin.firestore();

async function main() {
  const ref = db.collection('listings').doc(LISTING_ID);
  const snap = await ref.get();

  if (!snap.exists) {
    console.error(`❌ Listing ${LISTING_ID} introuvable.`);
    process.exit(1);
  }

  const data = snap.data();
  const status = String(data.status ?? '').trim();
  const modStatus = String(data.moderationStatus ?? '').trim();

  console.log(`📄 ${LISTING_ID}`);
  console.log(`   Titre    : ${data.title}`);
  console.log(`   Status   : ${status}`);
  console.log(`   Modérat. : ${modStatus}`);
  console.log(`   Risk     : ${data.riskScore}`);

  if (status === 'active') {
    console.log('\n✅ Déjà active, rien à faire.');
    return;
  }

  if (!APPLY) {
    console.log('\n🔍 Dry run. Sera mis à jour :');
    console.log('   status          → active');
    console.log('   moderationStatus→ approved');
    console.log('   visibility      → public');
    console.log('   publishedAt     → now');
    console.log('   autoPublishAfter→ null');
    console.log('\nRelance avec --apply pour appliquer.');
    return;
  }

  await ref.set({
    status: 'active',
    moderationStatus: 'approved',
    visibility: 'public',
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    autoPublishAfter: null,
  }, { merge: true });

  console.log('\n✅ Annonce publiée avec succès !');
}

main().catch((err) => {
  console.error('Erreur :', err.message);
  process.exitCode = 1;
});
