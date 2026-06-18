import { applicationDefault, getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
if (!getApps().length) initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const apply = process.argv.includes("--apply");
const aliases = ["phone", "telephone", "contactPhone", "phoneNumber"];
let scanned = 0, found = 0;
for (const collectionName of ["listings", "offers"]) {
  let cursor = null;
  while (true) {
    let query = db.collection(collectionName).orderBy("__name__").limit(300);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data();
      const phone = aliases.map((k) => String(data[k] || "").trim()).find(Boolean);
      if (!phone) continue;
      found++;
      console.log(`${apply ? "MIGRATE" : "DRY"} ${collectionName}/${doc.id}`);
      if (apply) {
        const ownerId = String(data.ownerId || data.userId || data.uid || "").trim();
        batch.set(db.collection("listingPrivateContacts").doc(doc.id), {
          listingId: doc.id, ownerId, phone, hidePhone: data.hidePhone === true,
          sourceCollection: collectionName,
          createdAt: data.createdAt || FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        const cleanup = { hidePhone: data.hidePhone === true, privateContactMigratedAt: FieldValue.serverTimestamp() };
        for (const key of aliases) cleanup[key] = FieldValue.delete();
        batch.set(doc.ref, cleanup, { merge: true });
      }
    }
    if (apply) await batch.commit();
    cursor = snap.docs.at(-1);
  }
}
console.log(JSON.stringify({ apply, scanned, found }, null, 2));
