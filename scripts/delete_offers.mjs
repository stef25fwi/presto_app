import admin from "firebase-admin";

admin.initializeApp(); // utilise GOOGLE_APPLICATION_CREDENTIALS
const db = admin.firestore();

async function deleteCollection(path, batchSize = 400) {
  const col = db.collection(path);

  while (true) {
    const snap = await col.limit(batchSize).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
  console.log(`✅ Deleted all docs in ${path}`);
}

await deleteCollection("offers");
process.exit(0);
