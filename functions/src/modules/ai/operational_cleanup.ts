import crypto from "node:crypto";

import admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { PROJECT_REGION } from "../../config/env";
import { logger } from "../../core/logger";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const AUDIO_CLEANUP_COLLECTION = "_ai_audio_cleanup";
const DEFAULT_AUDIO_RETENTION_MS = 30 * 60 * 1000;

function cleanupDocumentId(uid: string, storagePath: string): string {
  return crypto
    .createHash("sha256")
    .update(`${uid}|${storagePath}`)
    .digest("hex");
}

export async function scheduleAudioCleanup(options: {
  uid: string;
  storagePath: string;
  requestId: string;
  retentionMs?: number;
}): Promise<void> {
  if (!options.storagePath) return;
  const retentionMs = Math.min(
    24 * 60 * 60 * 1000,
    Math.max(5 * 60 * 1000, options.retentionMs ?? DEFAULT_AUDIO_RETENTION_MS),
  );
  const deleteAfter = admin.firestore.Timestamp.fromMillis(Date.now() + retentionMs);
  const id = cleanupDocumentId(options.uid, options.storagePath);
  await admin
    .firestore()
    .collection(AUDIO_CLEANUP_COLLECTION)
    .doc(id)
    .set(
      {
        uid: options.uid,
        storagePath: options.storagePath,
        requestId: options.requestId,
        status: "scheduled",
        deleteAfter,
        expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + retentionMs + 7 * 24 * 60 * 60 * 1000,
        ),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function deleteExpiredAudioBatch(limit = 100): Promise<number> {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await admin
    .firestore()
    .collection(AUDIO_CLEANUP_COLLECTION)
    .where("deleteAfter", "<=", now)
    .orderBy("deleteAfter", "asc")
    .limit(limit)
    .get();
  let deleted = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const storagePath = typeof data.storagePath === "string" ? data.storagePath : "";
    if (storagePath) {
      await admin
        .storage()
        .bucket()
        .file(storagePath)
        .delete({ ignoreNotFound: true })
        .catch((error) => {
          logger.warn("ai.audio_cleanup.storage_delete_failed", {
            documentId: doc.id,
            errorName: error instanceof Error ? error.name : "Error",
          });
        });
    }
    await doc.ref.delete();
    deleted += 1;
  }
  return deleted;
}

async function purgeExpiredCollection(
  collection: string,
  limit = 250,
): Promise<number> {
  const snapshot = await admin
    .firestore()
    .collection(collection)
    .where("expiresAt", "<=", admin.firestore.Timestamp.now())
    .orderBy("expiresAt", "asc")
    .limit(limit)
    .get();
  if (snapshot.empty) return 0;
  const batch = admin.firestore().batch();
  for (const doc of snapshot.docs) batch.delete(doc.ref);
  await batch.commit();
  return snapshot.size;
}

export const purgeExpiredAiAudio = onSchedule(
  {
    region: PROJECT_REGION,
    schedule: "every 15 minutes",
    timeZone: "Europe/Paris",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    let total = 0;
    for (let page = 0; page < 5; page += 1) {
      const count = await deleteExpiredAudioBatch(100);
      total += count;
      if (count < 100) break;
    }
    logger.info("ai.audio_cleanup.completed", { deleted: total });
  },
);

export const purgeExpiredAiOperationalData = onSchedule(
  {
    region: PROJECT_REGION,
    schedule: "every day 03:35",
    timeZone: "Europe/Paris",
    timeoutSeconds: 180,
    memory: "256MiB",
  },
  async () => {
    const collections = [
      "_ai_idempotency",
      "_rate_limits",
      "_ai_metrics_daily",
      AUDIO_CLEANUP_COLLECTION,
    ];
    const deleted: Record<string, number> = {};
    for (const collection of collections) {
      let total = 0;
      for (let page = 0; page < 5; page += 1) {
        const count = await purgeExpiredCollection(collection);
        total += count;
        if (count < 250) break;
      }
      deleted[collection] = total;
    }
    logger.info("ai.operational_cleanup.completed", { deleted });
  },
);
