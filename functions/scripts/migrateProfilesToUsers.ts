import admin from "firebase-admin";

import { initAdmin, normalizeString, parseCommonArgs } from "./_shared";

const BLOCKED_FIELDS = new Set([
  "roles",
  "role",
  "admin",
  "isAdmin",
  "superadmin",
  "superAdmin",
  "moderator",
  "isModerator",
  "trustedSeller",
  "verified",
  "isVerified",
]);

function sanitizeProfilePayload(data: Record<string, unknown>): Record<string, unknown> {
  const sanitized: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (BLOCKED_FIELDS.has(key)) {
      continue;
    }
    sanitized[key] = value;
  }
  return sanitized;
}

async function migrateCollection(
  db: FirebaseFirestore.Firestore,
  collectionName: string,
  dryRun: boolean,
) {
  const snapshot = await db.collection(collectionName).get();
  let migrated = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const profileDoc of snapshot.docs) {
    const data = profileDoc.data() as Record<string, unknown>;
    const userId = normalizeString(profileDoc.id || data.userId || data.uid);
    if (!userId) {
      continue;
    }

    const userRef = db.collection("users").doc(userId);
    const payload = {
      ...sanitizeProfilePayload(data),
      migratedFrom: `${collectionName}/${profileDoc.id}`,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (dryRun) {
      console.log(`[dry-run] ${collectionName}/${profileDoc.id} -> users/${userId}`);
      migrated += 1;
      continue;
    }

    batch.set(userRef, payload, { merge: true });
    batchCount += 1;
    migrated += 1;
    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (!dryRun && batchCount > 0) {
    await batch.commit();
  }

  return migrated;
}

async function main() {
  const options = parseCommonArgs(process.argv);
  const db = initAdmin(options.projectId);
  const migratedProfiles = await migrateCollection(db, "profiles", options.dryRun);
  const migratedUserProfiles = await migrateCollection(db, "user_profiles", options.dryRun);

  console.log(JSON.stringify({
    dryRun: options.dryRun,
    migratedProfiles,
    migratedUserProfiles,
  }, null, 2));
}

void main().catch((error) => {
  console.error("[migrateProfilesToUsers] failed", error);
  process.exitCode = 1;
});