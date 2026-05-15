import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { logger } from "firebase-functions";

/**
 * Purge les fichiers orphelins du bucket Storage (offers_raw/) qui n'ont pas
 * été référencés dans un listing Firestore depuis plus de 24 heures.
 * Tourne chaque nuit à 2 h (UTC).
 */
export const purgeOrphanedStorageFiles = onSchedule({
  schedule: "0 2 * * *",
  region: PROJECT_REGION,
  timeoutSeconds: 540,
}, async () => {
  const bucket = admin.storage().bucket();
  const cutoff = Date.now() - 24 * 60 * 60 * 1000; // 24 h
  let deletedCount = 0;

  const [files] = await bucket.getFiles({ prefix: "offers_raw/", maxResults: 500 });

  for (const file of files) {
    const metadata = file.metadata;
    const timeCreated = new Date(metadata.timeCreated ?? 0).getTime();
    if (timeCreated >= cutoff) continue;

    // Vérifie qu'aucun listing Firestore ne référence ce fichier
    const storagePath = file.name;
    const snap = await db
      .collection(COLLECTIONS.listings)
      .where("media", "array-contains", { storagePath })
      .limit(1)
      .get();

    if (snap.empty) {
      await file.delete().catch(() => {}); // best effort
      deletedCount++;
      logger.info("storage_orphan_deleted", { storagePath });
    }
  }

  logger.info("storage_cleanup_complete", {
    scannedFiles: files.length,
    deletedCount,
  });
});
