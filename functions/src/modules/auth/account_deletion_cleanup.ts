import admin from "../../core/firebase_admin_compat";

import { db } from "../../core/firestore";

const BATCH_WRITE_LIMIT = 400;

/**
 * Retire immédiatement du marché toutes les annonces appartenant au compte.
 * Les documents sont conservés pour l'audit, la facturation et le traitement
 * des litiges, mais l'identité publique est anonymisée.
 */
export async function archiveUserListings(uid: string): Promise<number> {
  const snapshot = await db
    .collection("listings")
    .where("ownerId", "==", uid)
    .get();

  let batch = db.batch();
  let pending = 0;
  let updated = 0;

  for (const document of snapshot.docs) {
    batch.set(
      document.ref,
      {
        status: "deleted",
        visibility: "private",
        ownerDisplayName: "Utilisateur supprimé",
        ownerPhotoUrl: null,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletedReason: "account_deleted",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    batch.delete(db.collection("listingPrivateContacts").doc(document.id));
    pending += 2;
    updated += 1;

    if (pending >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  if (pending > 0) await batch.commit();
  return updated;
}
