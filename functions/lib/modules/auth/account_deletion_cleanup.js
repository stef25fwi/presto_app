"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.archiveUserListings = archiveUserListings;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("../../core/firestore");
const BATCH_WRITE_LIMIT = 400;
/**
 * Retire immédiatement du marché toutes les annonces appartenant au compte.
 * Les documents sont conservés pour l'audit, la facturation et le traitement
 * des litiges, mais l'identité publique est anonymisée.
 */
async function archiveUserListings(uid) {
    const snapshot = await firestore_1.db
        .collection("listings")
        .where("ownerId", "==", uid)
        .get();
    let batch = firestore_1.db.batch();
    let pending = 0;
    let updated = 0;
    for (const document of snapshot.docs) {
        batch.set(document.ref, {
            status: "deleted",
            visibility: "private",
            ownerDisplayName: "Utilisateur supprimé",
            ownerPhotoUrl: null,
            deletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            deletedReason: "account_deleted",
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        batch.delete(firestore_1.db.collection("listingPrivateContacts").doc(document.id));
        pending += 2;
        updated += 1;
        if (pending >= BATCH_WRITE_LIMIT) {
            await batch.commit();
            batch = firestore_1.db.batch();
            pending = 0;
        }
    }
    if (pending > 0)
        await batch.commit();
    return updated;
}
//# sourceMappingURL=account_deletion_cleanup.js.map