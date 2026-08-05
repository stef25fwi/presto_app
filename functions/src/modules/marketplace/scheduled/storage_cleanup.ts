import admin from "../../../core/firebase_admin_compat";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../../shared/constants";
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
    db.collection(COLLECTIONS.listingDrafts).limit(1000).get(),
    db.collection(LEGACY_COLLECTIONS.listingDrafts).limit(1000).get(),
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

/**
 * TTL — Purge les brouillons d'annonce ABANDONNÉS : documents listingDrafts
 * encore au statut "draft" (jamais soumis) et inactifs depuis plus de 7 jours.
 * Supprime aussi leurs médias Storage. Tourne chaque nuit à 3 h (UTC).
 *
 * Sécurité : ne touche QUE les brouillons explicitement "draft". Les statuts
 * "submitted"/"pending"/etc. (devenus des annonces) sont ignorés.
 */
export const purgeAbandonedListingDrafts = onSchedule({
  schedule: "0 3 * * *",
  region: PROJECT_REGION,
  timeoutSeconds: 540,
}, async () => {
  const ABANDON_AFTER_MS = 7 * 24 * 60 * 60 * 1000; // 7 jours
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - ABANDON_AFTER_MS);
  const bucket = admin.storage().bucket();

  let scanned = 0;
  let deletedDrafts = 0;
  let deletedMedia = 0;

  for (const collectionName of [COLLECTIONS.listingDrafts, LEGACY_COLLECTIONS.listingDrafts]) {
    let snapshot;
    try {
      snapshot = await db
        .collection(collectionName)
        .where("updatedAt", "<", cutoff)
        .limit(300)
        .get();
    } catch (error) {
      logger.warn("abandoned_drafts_query_failed", { collectionName, error: String(error) });
      continue;
    }

    for (const doc of snapshot.docs) {
      scanned += 1;
      const data = doc.data() as Record<string, unknown>;
      const status = String(data.status ?? "").trim().toLowerCase();
      // On ne supprime que les brouillons jamais soumis.
      if (status !== "draft") continue;

      for (const storagePath of collectMediaStoragePaths(data)) {
        await bucket.file(storagePath).delete().catch((error) => {
          logger.warn("abandoned_draft_media_delete_failed", { storagePath, error: String(error) });
        });
        deletedMedia += 1;
      }

      await doc.ref.delete().catch((error) => {
        logger.warn("abandoned_draft_delete_failed", { draftId: doc.id, error: String(error) });
      });
      deletedDrafts += 1;
      logger.info("abandoned_draft_deleted", { collectionName, draftId: doc.id });
    }
  }

  logger.info("abandoned_drafts_cleanup_complete", { scanned, deletedDrafts, deletedMedia });
});
