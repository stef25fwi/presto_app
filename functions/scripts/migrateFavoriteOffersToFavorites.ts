import admin from "firebase-admin";

import { initAdmin, normalizeString, parseCommonArgs } from "./_shared";

async function main() {
  const options = parseCommonArgs(process.argv);
  const db = initAdmin(options.projectId);
  const users = await db.collection("users").get();

  let scannedUsers = 0;
  let migrated = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const userDoc of users.docs) {
    scannedUsers += 1;
    const favoritesSnap = await userDoc.ref.collection("favoriteOffers").get();
    for (const favoriteDoc of favoritesSnap.docs) {
      const listingId = normalizeString(favoriteDoc.id || favoriteDoc.data().listingId);
      if (!listingId) {
        continue;
      }

      const targetId = `${userDoc.id}_${listingId}`;
      const targetRef = db.collection("favorites").doc(targetId);
      const targetSnap = await targetRef.get();
      if (targetSnap.exists) {
        continue;
      }

      const payload = {
        id: targetId,
        userId: userDoc.id,
        listingId,
        createdAt:
          (favoriteDoc.data().createdAt as FirebaseFirestore.Timestamp | undefined) ||
          admin.firestore.Timestamp.now(),
        migratedFrom: `users/${userDoc.id}/favoriteOffers/${favoriteDoc.id}`,
      };

      if (options.dryRun) {
        console.log(`[dry-run] ${payload.migratedFrom} -> favorites/${targetId}`);
        migrated += 1;
        continue;
      }

      batch.set(targetRef, payload, { merge: false });
      batchCount += 1;
      migrated += 1;
      if (batchCount >= 400) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
  }

  if (!options.dryRun && batchCount > 0) {
    await batch.commit();
  }

  console.log(JSON.stringify({ scannedUsers, migrated, dryRun: options.dryRun }, null, 2));
}

void main().catch((error) => {
  console.error("[migrateFavoriteOffersToFavorites] failed", error);
  process.exitCode = 1;
});