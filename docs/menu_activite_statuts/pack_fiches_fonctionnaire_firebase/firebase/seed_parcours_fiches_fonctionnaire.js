/**
 * Import Firestore — parcoursFiches
 * Usage:
 * 1) npm i firebase-admin
 * 2) export GOOGLE_APPLICATION_CREDENTIALS="/chemin/service-account.json"
 * 3) node firebase/seed_parcours_fiches_fonctionnaire.js
 */
const admin = require('firebase-admin');
const path = require('path');
const data = require('./parcours_fiches_fonctionnaire.json');

admin.initializeApp();
const db = admin.firestore();

async function main() {
  const collectionName = process.env.FIRESTORE_COLLECTION || 'parcoursFiches';
  let batch = db.batch();
  let count = 0;
  for (const fiche of data) {
    const ref = db.collection(collectionName).doc(fiche.id_fiche);
    batch.set(ref, fiche, { merge: true });
    count++;
    if (count % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  await batch.commit();
  console.log(`Import terminé: ${count} fiches dans ${collectionName}`);
}
main().catch((err) => {
  console.error(err);
  process.exit(1);
});
