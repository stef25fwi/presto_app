"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.purgeAbandonedListingDrafts = exports.purgeOrphanedStorageFiles = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const firebase_functions_1 = require("firebase-functions");
function collectMediaStoragePaths(data) {
    const media = Array.isArray(data.media) ? data.media : [];
    return media
        .filter((entry) => entry != null && typeof entry === "object")
        .map((entry) => String(entry.storagePath || "").trim())
        .filter((storagePath) => storagePath.length > 0);
}
async function loadReferencedRawStoragePaths() {
    const referenced = new Set();
    const snapshots = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.listings).limit(1000).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.listingDrafts).limit(1000).get(),
        firestore_1.db.collection(constants_1.LEGACY_COLLECTIONS.listingDrafts).limit(1000).get(),
    ]);
    for (const snapshot of snapshots) {
        for (const doc of snapshot.docs) {
            for (const storagePath of collectMediaStoragePaths(doc.data())) {
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
exports.purgeOrphanedStorageFiles = (0, scheduler_1.onSchedule)({
    schedule: "0 2 * * *",
    region: env_1.PROJECT_REGION,
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
        if (timeCreated >= cutoff)
            continue;
        const storagePath = file.name;
        if (referencedRawPaths.has(storagePath))
            continue;
        await file.delete().catch((error) => {
            firebase_functions_1.logger.warn("storage_orphan_delete_failed", { storagePath, error: String(error) });
        });
        deletedCount++;
        firebase_functions_1.logger.info("storage_orphan_deleted", { storagePath });
    }
    firebase_functions_1.logger.info("storage_cleanup_complete", {
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
exports.purgeAbandonedListingDrafts = (0, scheduler_1.onSchedule)({
    schedule: "0 3 * * *",
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 540,
}, async () => {
    const ABANDON_AFTER_MS = 7 * 24 * 60 * 60 * 1000; // 7 jours
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - ABANDON_AFTER_MS);
    const bucket = admin.storage().bucket();
    let scanned = 0;
    let deletedDrafts = 0;
    let deletedMedia = 0;
    for (const collectionName of [constants_1.COLLECTIONS.listingDrafts, constants_1.LEGACY_COLLECTIONS.listingDrafts]) {
        let snapshot;
        try {
            snapshot = await firestore_1.db
                .collection(collectionName)
                .where("updatedAt", "<", cutoff)
                .limit(300)
                .get();
        }
        catch (error) {
            firebase_functions_1.logger.warn("abandoned_drafts_query_failed", { collectionName, error: String(error) });
            continue;
        }
        for (const doc of snapshot.docs) {
            scanned += 1;
            const data = doc.data();
            const status = String(data.status ?? "").trim().toLowerCase();
            // On ne supprime que les brouillons jamais soumis.
            if (status !== "draft")
                continue;
            for (const storagePath of collectMediaStoragePaths(data)) {
                await bucket.file(storagePath).delete().catch((error) => {
                    firebase_functions_1.logger.warn("abandoned_draft_media_delete_failed", { storagePath, error: String(error) });
                });
                deletedMedia += 1;
            }
            await doc.ref.delete().catch((error) => {
                firebase_functions_1.logger.warn("abandoned_draft_delete_failed", { draftId: doc.id, error: String(error) });
            });
            deletedDrafts += 1;
            firebase_functions_1.logger.info("abandoned_draft_deleted", { collectionName, draftId: doc.id });
        }
    }
    firebase_functions_1.logger.info("abandoned_drafts_cleanup_complete", { scanned, deletedDrafts, deletedMedia });
});
//# sourceMappingURL=storage_cleanup.js.map