#!/usr/bin/env node

/**
 * Purge une collection Firestore + recrée 15 annonces "compatibles affichage".
 * Usage:
 *   export FIREBASE_PROJECT_ID=presto-app-74abe
 *   export GOOGLE_APPLICATION_CREDENTIALS=/chemin/serviceAccount.json
 *   node scripts/reset_annonces.js
 *
 * Prérequis:
 *  - Un service account JSON (télécharge depuis Firebase Console → Project Settings)
 *  - Variables d'env configurées comme ci-dessus
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
if (!PROJECT_ID) {
  console.error(
    "❌ FIREBASE_PROJECT_ID manquant. Ex: export FIREBASE_PROJECT_ID=presto-app-74abe"
  );
  process.exit(1);
}

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!credPath) {
  console.error(
    "❌ GOOGLE_APPLICATION_CREDENTIALS manquant (chemin vers serviceAccount.json)."
  );
  console.error("   Télécharge depuis: https://console.firebase.google.com → Project Settings → Service Accounts");
  process.exit(1);
}

if (!fs.existsSync(credPath)) {
  console.error(`❌ Fichier ${credPath} introuvable`);
  process.exit(1);
}

try {
  const serviceAccount = JSON.parse(fs.readFileSync(credPath, "utf8"));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: PROJECT_ID,
  });
} catch (e) {
  console.error("❌ Erreur lors de la lecture du service account:", e.message);
  process.exit(1);
}

const db = admin.firestore();
const COLLECTION = process.env.ANNONCES_COLLECTION || "offers";

async function deleteCollection(colName, batchSize = 400) {
  const colRef = db.collection(colName);
  let totalDeleted = 0;

  while (true) {
    const snap = await colRef
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(batchSize)
      .get();

    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();

    totalDeleted += snap.size;
    console.log(`  🗑️  supprimés: ${snap.size} (total: ${totalDeleted})`);
  }

  console.log(`✅ ${totalDeleted} annonces supprimées`);
}

function makeAnnonce(i) {
  // Villes/CP Guadeloupe (exemples)
  const places = [
    { city: "Pointe-à-Pitre", postalCode: "97110", lat: 16.2369, lng: -61.5336 },
    { city: "Les Abymes", postalCode: "97139", lat: 16.2736, lng: -61.5045 },
    { city: "Baie-Mahault", postalCode: "97122", lat: 16.267, lng: -61.585 },
    { city: "Le Gosier", postalCode: "97190", lat: 16.2045, lng: -61.4925 },
    { city: "Sainte-Anne", postalCode: "97180", lat: 16.2264, lng: -61.3817 },
    { city: "Basse-Terre", postalCode: "97100", lat: 15.9985, lng: -61.732 },
  ];

  const jobs = [
    {
      category: "Bricolage",
      title: "Monter un meuble + fixation murale",
      priceMin: 40,
      priceMax: 90,
    },
    {
      category: "Jardinage",
      title: "Tonte + débroussaillage petit jardin",
      priceMin: 50,
      priceMax: 120,
    },
    {
      category: "Ménage",
      title: "Ménage 2h (appartement)",
      priceMin: 35,
      priceMax: 70,
    },
    {
      category: "Plomberie",
      title: "Fuite sous évier + remplacement joint",
      priceMin: 60,
      priceMax: 140,
    },
    {
      category: "Électricité",
      title: "Remplacer 2 luminaires",
      priceMin: 50,
      priceMax: 120,
    },
    {
      category: "Coiffure",
      title: "Tresses / braids à domicile",
      priceMin: 60,
      priceMax: 160,
    },
    {
      category: "Babysitting",
      title: "Garde 1 soirée (19h–23h)",
      priceMin: 45,
      priceMax: 100,
    },
    {
      category: "Livraison",
      title: "Livraison courses (supermarché)",
      priceMin: 20,
      priceMax: 45,
    },
    {
      category: "Déménagement",
      title: "Aide chargement/déchargement 2h",
      priceMin: 60,
      priceMax: 150,
    },
    {
      category: "Informatique",
      title: "Installation imprimante + Wi-Fi",
      priceMin: 35,
      priceMax: 80,
    },
    {
      category: "Cours",
      title: "Cours maths collège (1h)",
      priceMin: 20,
      priceMax: 40,
    },
    {
      category: "Peinture",
      title: "Peinture mur (petite pièce)",
      priceMin: 80,
      priceMax: 250,
    },
    {
      category: "Nettoyage",
      title: "Nettoyage terrasse + karcher",
      priceMin: 60,
      priceMax: 180,
    },
    {
      category: "Réparation",
      title: "Réparer porte/charnière",
      priceMin: 35,
      priceMax: 90,
    },
    {
      category: "DJ",
      title: "DJ anniversaire 3h (matériel inclus)",
      priceMin: 250,
      priceMax: 450,
    },
  ];

  const p = places[i % places.length];
  const j = jobs[i % jobs.length];

  const now = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - i * 60 * 1000)
  ); // étalé sur 15 minutes

  return {
    // ✅ Champs "affichage" fréquents
    status: "published",
    isActive: true,
    visibility: { isPublic: true },
    isDeleted: false,

    title: j.title,
    description:
      `Annonce test #${i + 1} — ${j.category}. ` +
      "Je cherche quelqu'un rapidement. Merci d'indiquer votre dispo et votre prix.",

    category: j.category,
    city: p.city,
    postalCode: p.postalCode,
    location: new admin.firestore.GeoPoint(p.lat, p.lng),

    budget: j.priceMax,
    budgetValue: j.priceMax,
    currency: "EUR",

    createdAt: now,
    updatedAt: now,

    // Optionnel utile pour tri/UX
    urgency: i % 3 === 0 ? "high" : "normal",
    source: "seed_script",
    userId: "system_seed",
  };
}

async function seed(colName, count = 15) {
  const colRef = db.collection(colName);
  const batch = db.batch();

  for (let i = 0; i < count; i++) {
    const ref = colRef.doc(); // auto-id
    batch.set(ref, makeAnnonce(i));
  }

  await batch.commit();
  console.log(`✅ ${count} annonces recréées dans ${colName}`);
}

(async () => {
  try {
    console.log("🔄 Reset annonces Firestore");
    console.log(`   Projet: ${PROJECT_ID}`);
    console.log(`   Collection: ${COLLECTION}`);
    console.log("");

    console.log("🗑️  Suppression des annonces...");
    await deleteCollection(COLLECTION);
    console.log("");

    console.log("📝 Création de 15 annonces...");
    await seed(COLLECTION, 15);
    console.log("");

    console.log("✨ Terminé !");
    console.log("");
    console.log("🚀 Prochaines étapes:");
    console.log("   1. Ouvre l'app");
    console.log("   2. Va sur 'Je consulte les offres'");
    console.log("   3. Les 15 annonces doivent s'afficher 🎉");

    process.exit(0);
  } catch (error) {
    console.error("❌ Erreur:", error.message);
    process.exit(1);
  }
})();
