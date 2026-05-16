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
exports.purgeOrphanedStorageFiles = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const firebase_functions_1 = require("firebase-functions");
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
    const [files] = await bucket.getFiles({ prefix: "offers_raw/", maxResults: 500 });
    for (const file of files) {
        const metadata = file.metadata;
        const timeCreated = new Date(metadata.timeCreated ?? 0).getTime();
        if (timeCreated >= cutoff)
            continue;
        // Vérifie qu'aucun listing Firestore ne référence ce fichier
        const storagePath = file.name;
        const snap = await firestore_1.db
            .collection(constants_1.COLLECTIONS.listings)
            .where("media", "array-contains", { storagePath })
            .limit(1)
            .get();
        if (snap.empty) {
            await file.delete().catch(() => { }); // best effort
            deletedCount++;
            firebase_functions_1.logger.info("storage_orphan_deleted", { storagePath });
        }
    }
    firebase_functions_1.logger.info("storage_cleanup_complete", {
        scannedFiles: files.length,
        deletedCount,
    });
});
//# sourceMappingURL=storage_cleanup.js.map