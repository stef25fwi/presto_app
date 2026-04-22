// Audit rapide : y a-t-il des annonces visibles publiquement en base ?
// Usage : node tools/audit_public_offers_listings.cjs

const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'presto-app-74abe';

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}

const db = admin.firestore();

function fmt(ts) {
  if (!ts) return '-';
  try {
    return ts.toDate().toISOString().slice(0, 19);
  } catch {
    return String(ts);
  }
}

async function scanListings() {
  console.log('\n=== listings (status==active AND visibility==public) ===');
  const snap = await db
    .collection('listings')
    .where('status', '==', 'active')
    .where('visibility', '==', 'public')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();
  console.log(`total (page 5 max): ${snap.size}`);
  snap.forEach((doc) => {
    const d = doc.data();
    console.log(
      `  - ${doc.id} | title="${(d.title || '').slice(0, 40)}" | cat=${d.categoryId || '-'} | createdAt=${fmt(d.createdAt)}`,
    );
  });

  const count = await db
    .collection('listings')
    .where('status', '==', 'active')
    .where('visibility', '==', 'public')
    .count()
    .get();
  console.log(`COUNT total: ${count.data().count}`);
}

async function scanOffers() {
  console.log('\n=== offers (status==active) ===');
  const snap = await db
    .collection('offers')
    .where('status', '==', 'active')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();
  console.log(`total (page 5 max): ${snap.size}`);
  snap.forEach((doc) => {
    const d = doc.data();
    console.log(
      `  - ${doc.id} | title="${(d.title || '').slice(0, 40)}" | createdAt=${fmt(d.createdAt)}`,
    );
  });

  const count = await db
    .collection('offers')
    .where('status', '==', 'active')
    .count()
    .get();
  console.log(`COUNT offers status==active: ${count.data().count}`);
}

async function sampleAllListings() {
  console.log('\n=== listings (sample 5, tous statuts) ===');
  const snap = await db.collection('listings').limit(5).get();
  snap.forEach((doc) => {
    const d = doc.data();
    console.log(
      `  - ${doc.id} | status=${d.status} | visibility=${d.visibility} | createdAt=${fmt(d.createdAt)}`,
    );
  });
  const all = await db.collection('listings').count().get();
  console.log(`COUNT TOTAL listings: ${all.data().count}`);
}

(async () => {
  try {
    await scanListings();
    await scanOffers();
    await sampleAllListings();
  } catch (error) {
    console.error('Erreur:', error);
    process.exit(1);
  }
})();
