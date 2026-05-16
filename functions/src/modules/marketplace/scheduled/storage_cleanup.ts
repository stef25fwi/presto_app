import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { logger } from "firebase-functions";

function collectMediaStoragePaths(data: Record<string, unknown>): string[] {
  const media = Array.isArray(data.media) ? data.media : [];
  return media
    .filter((entry): entry is Record<string, unknown> => entry != null && typeof entry === "object")
    .map((entry) => String(entry.storagePath || "").trim())
    .filter((storagePath) => storagePath.length > 0);
}

async function loadReferencedRawStoragePaths(): Promise<Set<string>> {
  const referenced = new Set<string>();
  const snapshots = await Promise.all([
    db.collection(COLLECTIONS.listings).limit(1000).get(),
    db.collection(COLLECTIONS.listingDraftsV2).limit(1000).get(),
    db.collection(COLLECTIONS.listingDrafts).limit(1000).get(),
  ]);

  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      for (const storagePath of collectMediaStoragePaths(doc.data() as Record<string, unknown>)) {
        if (storagePath.startsWith("offers_raw/")) {
          referenced.add(storagePath);
        }
      }
    }
  }

  return referenced;
}

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
  const referencedRawPaths = await loadReferencedRawStoragePaths();

  const [files] = await bucket.getFiles({ prefix: "offers_raw/", maxResults: 500 });

  for (const file of files) {
    const metadata = file.metadata;
    const timeCreated = new Date(metadata.timeCreated ?? 0).getTime();
    if (timeCreated >= cutoff) continue;

    const storagePath = file.name;
    if (referencedRawPaths.has(storagePath)) continue;

    await file.delete().catch((error) => {
      logger.warn("storage_orphan_delete_failed", { storagePath, error: String(error) });
    });
    deletedCount++;
    logger.info("storage_orphan_deleted", { storagePath });
  }

  logger.info("storage_cleanup_complete", {
    scannedFiles: files.length,
    deletedCount,
  });
});
