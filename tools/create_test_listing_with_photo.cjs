#!/usr/bin/env node
"use strict";

/**
 * Crée une annonce de test dans Firestore avec une photo uploadée depuis assets/images/.
 *
 * Usage:
 *   node tools/create_test_listing_with_photo.cjs [--image=jobfait.webp] [--delete]
 *
 *   --image=<nom>   Nom du fichier dans assets/images/ (défaut: jobfait.webp)
 *   --delete        Supprime toutes les annonces créées avec ce script (seedTag)
 */

const admin = require("firebase-admin");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "presto-app-74abe";
const BUCKET_NAME = `${PROJECT_ID}.firebasestorage.app`;
const SEED_TAG = "test-listing-photo-2026";
const TEST_OWNER_ID = "test-photo-seed-owner";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const bucket = admin.storage().bucket(BUCKET_NAME);

// ── CLI args ──
const DELETE_MODE = process.argv.includes("--delete");
const imageArg =
  (process.argv.find((a) => a.startsWith("--image=")) || "--image=jobfait.webp").split("=")[1];

// ── Helpers ──
function contentTypeFor(ext) {
  switch (ext.toLowerCase()) {
    case ".webp": return "image/webp";
    case ".png":  return "image/png";
    case ".jpg":
    case ".jpeg": return "image/jpeg";
    default:       return "application/octet-stream";
  }
}

/**
 * Upload un fichier local vers Firebase Storage.
 * Utilise le mécanisme natif Firebase de "download token" (firebaseStorageDownloadTokens)
 * pour construire une URL de téléchargement publique qui bypass les Storage Rules.
 */
async function uploadPhoto(localPath, storagePath) {
  const buffer = fs.readFileSync(localPath);
  const ext = path.extname(localPath);
  const contentType = contentTypeFor(ext);
  const downloadToken = crypto.randomUUID();

  const file = bucket.file(storagePath);
  await file.save(buffer, {
    resumable: false,
    metadata: {
      contentType,
      metadata: {
        // Ce champ est reconnu par Firebase Storage pour générer un downloadUrl permanent
        firebaseStorageDownloadTokens: downloadToken,
      },
    },
  });

  const downloadUrl =
    `https://firebasestorage.googleapis.com/v0/b/${BUCKET_NAME}/o/${encodeURIComponent(storagePath)}?alt=media&token=${downloadToken}`;

  return { storagePath, downloadUrl, contentType, sizeBytes: buffer.length };
}

// ── Main ──
async function main() {
  // ── Mode suppression ──
  if (DELETE_MODE) {
    const snap = await db.collection("listings").where("seedTag", "==", SEED_TAG).get();
    if (snap.empty) {
      console.log("Aucune annonce de test trouvée à supprimer.");
      return;
    }
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    console.log(`✅ ${snap.size} annonce(s) de test supprimée(s).`);
    return;
  }

  // ── Mode création ──
  const assetsDir = path.resolve(__dirname, "..", "assets", "images");
  const localImagePath = path.join(assetsDir, imageArg);

  if (!fs.existsSync(localImagePath)) {
    const available = fs.readdirSync(assetsDir).join(", ");
    console.error(`❌ Image introuvable: ${localImagePath}`);
    console.error(`   Images disponibles: ${available}`);
    process.exitCode = 1;
    return;
  }

  const listingRef = db.collection("listings").doc();
  const listingId = listingRef.id;

  // Le chemin Storage suit la structure des règles: listings/{ownerId}/{listingId}/{fichier}
  const fileName = `photo_0${path.extname(localImagePath)}`;
  const storagePath = `listings/${TEST_OWNER_ID}/${listingId}/${fileName}`;

  // ── Étape 1 : Upload Storage ──
  console.log(`\n[1/3] Upload de l'image vers Firebase Storage…`);
  console.log(`  Fichier local : ${localImagePath}`);
  console.log(`  Chemin Storage: ${storagePath}`);

  const { downloadUrl, sizeBytes } = await uploadPhoto(localImagePath, storagePath);
  console.log(`  ✅ Upload OK (${sizeBytes} octets)`);
  console.log(`  downloadUrl  : ${downloadUrl.substring(0, 100)}…`);

  // ── Étape 2 : Création du document Firestore ──
  console.log(`\n[2/3] Création de l'annonce Firestore (listings/${listingId})…`);

  const now = admin.firestore.Timestamp.now();
  const media = [
    {
      downloadUrl,
      thumbnailUrl: downloadUrl,
      storagePath,
      index: 0,
      status: "ready",
      sizeBytes,
    },
  ];

  await listingRef.set({
    id: listingId,
    title: `[TEST PHOTO] Annonce pipeline image – ${imageArg}`,
    description:
      `Annonce créée automatiquement pour valider le pipeline photo.\n` +
      `Image: ${imageArg} | SeedTag: ${SEED_TAG}`,
    category: "services",
    subcategory: "autres",
    price: 42.0,
    currency: "EUR",
    city: "Paris",
    postalCode: "75001",
    country: "FR",
    status: "active",
    moderationStatus: "approved",
    mediaProcessingStatus: "completed",
    visibility: "public",
    media,
    thumbnailUrl: downloadUrl,
    imageUrls: [downloadUrl],
    ownerId: TEST_OWNER_ID,
    userId: TEST_OWNER_ID,
    advertiserName: "Test Photo Pipeline",
    isActive: true,
    isPublished: true,
    seedTag: SEED_TAG,
    createdAt: now,
    updatedAt: now,
    publishedAt: now,
  });

  console.log(`  ✅ Annonce créée`);

  // ── Étape 3 : Vérification lecture ──
  console.log(`\n[3/3] Vérification lecture Firestore…`);
  const doc = await listingRef.get();
  const data = doc.data();
  console.log(`  title    : ${data.title}`);
  console.log(`  status   : ${data.status}`);
  console.log(`  media    : ${data.media.length} élément(s)`);
  console.log(`  downloadUrl (media[0]): ${data.media[0].downloadUrl.substring(0, 100)}…`);

  console.log(`
╔══════════════════════════════════════════════════╗
║  ✅ Annonce de test créée avec succès             ║
║                                                    ║
║  ID Firestore : ${listingId.padEnd(32)} ║
║  Image        : ${imageArg.padEnd(32)} ║
║                                                    ║
║  Ouvrez l'appli et cherchez l'annonce :            ║
║    "[TEST PHOTO] Annonce pipeline image"           ║
║                                                    ║
║  Pour supprimer :                                  ║
║    node tools/create_test_listing_with_photo.cjs   ║
║         --delete                                   ║
╚══════════════════════════════════════════════════╝`);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
