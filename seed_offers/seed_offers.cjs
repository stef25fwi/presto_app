const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

const items = JSON.parse(fs.readFileSync("seed_offers.json", "utf8"));

(async () => {
  const batch = db.batch();
  for (const it of items) {
    const ref = db.collection("offers").doc(it.id);
    const payload = {
      ...it,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    delete payload.id;
    batch.set(ref, payload, { merge: true });
  }
  await batch.commit();
  console.log(`✅ ${items.length} offres injectées dans offers`);
})().catch((e) => {
  console.error("❌", e);
  process.exit(1);
});
