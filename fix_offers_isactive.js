#!/usr/bin/env node

/**
 * Script pour corriger les offres dans Firestore.
 *
 * Objectif:
 * - Backfill des champs requis par l'app (ex: `isActive`) sur les anciennes annonces.
 * - Backfill des champs nécessaires aux filtres de "Je consulte":
 *   `dept`, `regionCode`, `categoryId`, `cityId`, `cityCategoryKey`, `subcategory`, `budgetValue`.
 * - Optionnel: backfill `status: 'active'` si absent (compat legacy / règles).
 *
 * Par sécurité: on ne force PAS `isActive=true` si le champ existe déjà (ex: isActive=false).
 *
 * Usage:
 *   npm install
 *   # puis
 *   node fix_offers_isactive.js --dry-run
 *   node fix_offers_isactive.js
 *
 * Auth Admin:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/chemin/serviceAccount.json
 *   (ou place le fichier dans functions/serviceAccount.json)
 */

import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldPath, FieldValue, getFirestore } from 'firebase-admin/firestore';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const args = new Set(process.argv.slice(2));
const isDryRun = args.has('--dry-run');

const pageSize = (() => {
  const flag = [...args].find((a) => a.startsWith('--page-size='));
  if (!flag) return 450;
  const raw = flag.split('=')[1];
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 && n <= 500 ? n : 450;
})();

function resolveServiceAccountPath() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }

  const candidates = [
    path.join(__dirname, 'functions', 'serviceAccount.json'),
    path.join(process.cwd(), 'functions', 'serviceAccount.json'),
  ];

  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }

  return null;
}

// Initialiser Firebase Admin (service account local si dispo)
if (getApps().length === 0) {
  const credPath = resolveServiceAccountPath();
  if (credPath) {
    if (!fs.existsSync(credPath)) {
      console.error(`❌ Fichier service account introuvable: ${credPath}`);
      process.exit(1);
    }
    try {
      const serviceAccount = JSON.parse(fs.readFileSync(credPath, 'utf8'));
      initializeApp({ credential: cert(serviceAccount) });
      console.log(`🔐 Firebase Admin initialisé via service account: ${credPath}`);
    } catch (e) {
      console.error(
        '❌ Erreur lors de la lecture du service account (JSON invalide ?) :',
        e?.message ?? e
      );
      process.exit(1);
    }
  } else {
    // Tentative ADC (peut fonctionner en CI / environnement GCP)
    initializeApp();
    console.log(
      '🔐 Firebase Admin initialisé via Application Default Credentials (ADC)'
    );
    console.log(
      "   (Si ça échoue en local, fournis GOOGLE_APPLICATION_CREDENTIALS ou functions/serviceAccount.json)"
    );
  }
}

const db = getFirestore();

function slugId(input) {
  return String(input ?? '')
    .trim()
    .toLowerCase()
    .replace(/[àâä]/g, 'a')
    .replace(/ç/g, 'c')
    .replace(/[éèêë]/g, 'e')
    .replace(/[îï]/g, 'i')
    .replace(/[ôö]/g, 'o')
    .replace(/[ùûü]/g, 'u')
    .replace(/œ/g, 'oe')
    .replace(/[/\-’']/g, ' ')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/ /g, '-');
}

function deptFromPostal(cp) {
  const s = String(cp ?? '').trim();
  if (s.length < 2) return s;
  if (s.startsWith('97') || s.startsWith('98')) return s.length >= 3 ? s.slice(0, 3) : s;
  return s.slice(0, 2);
}

// kRegions (code -> nom) aligné avec l'app
const kRegions = {
  ARA: 'Auvergne-Rhône-Alpes',
  BFC: 'Bourgogne-Franche-Comté',
  BRE: 'Bretagne',
  CVL: 'Centre-Val de Loire',
  GES: 'Grand Est',
  HDF: 'Hauts-de-France',
  IDF: 'Île-de-France',
  NOR: 'Normandie',
  NAQ: 'Nouvelle-Aquitaine',
  OCC: 'Occitanie',
  PDL: 'Pays de la Loire',
  PACA: "Provence-Alpes-Côte d'Azur",
  COR: 'Corse',
  DOM: 'Outre-mer',
};

function inferRegionNameFromPostalCode(cp) {
  const s = String(cp ?? '').trim();
  if (s.length < 2) return null;

  // DOM / COM
  if (s.startsWith('97') || s.startsWith('98')) return 'Outre-mer';

  // Corse
  if (s.startsWith('20')) return 'Corse';

  const two = Number.parseInt(s.slice(0, 2), 10);
  if (!Number.isFinite(two)) return null;

  if (new Set([1, 3, 7, 15, 26, 38, 42, 43, 63, 69, 73, 74]).has(two)) return 'Auvergne-Rhône-Alpes';
  if (new Set([21, 25, 39, 58, 70, 71, 89, 90]).has(two)) return 'Bourgogne-Franche-Comté';
  if (new Set([22, 29, 35, 56]).has(two)) return 'Bretagne';
  if (new Set([18, 28, 36, 37, 41, 45]).has(two)) return 'Centre-Val de Loire';
  if (new Set([8, 10, 51, 52, 54, 55, 57, 67, 68, 88]).has(two)) return 'Grand Est';
  if (new Set([2, 59, 60, 62, 80]).has(two)) return 'Hauts-de-France';
  if (new Set([75, 77, 78, 91, 92, 93, 94, 95]).has(two)) return 'Île-de-France';
  if (new Set([14, 27, 50, 61, 76]).has(two)) return 'Normandie';
  if (new Set([16, 17, 19, 23, 24, 33, 40, 47, 64, 79, 86, 87]).has(two)) return 'Nouvelle-Aquitaine';
  if (new Set([9, 11, 12, 30, 31, 32, 34, 46, 48, 65, 66, 81, 82]).has(two)) return 'Occitanie';
  if (new Set([44, 49, 53, 72, 85]).has(two)) return 'Pays de la Loire';
  if (new Set([4, 5, 6, 13, 83, 84]).has(two)) return "Provence-Alpes-Côte d'Azur";

  return null;
}

function inferRegionCodeFromPostalCode(cp) {
  const name = inferRegionNameFromPostalCode(cp);
  if (!name) return null;
  for (const [code, regionName] of Object.entries(kRegions)) {
    if (regionName === name) return code;
  }
  return null;
}

async function fixAllOffers() {
  console.log(
    `🔄 Backfill des offres (isActive/status + champs filtres consult)${isDryRun ? ' [DRY-RUN]' : ''}`
  );

  try {
    const offersRef = db.collection('offers');

    let totalScanned = 0;
    let totalPatched = 0;
    let totalWrites = 0;
    let page = 0;
    let lastDoc = null;

    while (true) {
      page++;

      let q = offersRef
        .orderBy(FieldPath.documentId())
        .limit(pageSize);

      if (lastDoc) {
        q = q.startAfter(lastDoc);
      }

      const snapshot = await q.get();
      if (snapshot.empty) break;

      totalScanned += snapshot.size;
      console.log(`\n📄 Page ${page}: ${snapshot.size} docs`);

      let batch = db.batch();
      let batchWrites = 0;

      const flush = async () => {
        if (batchWrites <= 0) return;
        if (!isDryRun) await batch.commit();
        totalWrites += batchWrites;
        batch = db.batch();
        batchWrites = 0;
      };

      for (const doc of snapshot.docs) {
        const data = doc.data() ?? {};
        const update = {};

        // ✅ Backfill uniquement si le champ est absent (ne pas réactiver une annonce désactivée).
        if (!Object.prototype.hasOwnProperty.call(data, 'isActive')) {
          update.isActive = true;
        }

        // ✅ Backfill status legacy si absent (utile pour compat et debugging).
        if (!Object.prototype.hasOwnProperty.call(data, 'status')) {
          update.status = 'active';
        }

        // --- Champs nécessaires aux filtres "Je consulte" ---
        const category = (data.category ?? '').toString().trim();
        const location = (data.location ?? data.city ?? '').toString().trim();
        const postalCode = (data.postalCode ?? data.cp ?? '').toString().trim();
        const subcategory = (data.subcategory ?? data.subCategory ?? '').toString().trim();

        if (!Object.prototype.hasOwnProperty.call(data, 'subcategory') && subcategory) {
          update.subcategory = subcategory;
        }

        if (!Object.prototype.hasOwnProperty.call(data, 'categoryId') && category) {
          update.categoryId = category === 'Toutes catégories' ? null : slugId(category);
        }

        if (
          !Object.prototype.hasOwnProperty.call(data, 'cityId') &&
          location &&
          postalCode &&
          postalCode.length >= 3
        ) {
          update.cityId = `${postalCode}_${slugId(location)}`;
        }

        // cityCategoryKey dépend des 2 champs
        const categoryId = Object.prototype.hasOwnProperty.call(update, 'categoryId')
          ? update.categoryId
          : data.categoryId;
        const cityId = Object.prototype.hasOwnProperty.call(update, 'cityId')
          ? update.cityId
          : data.cityId;

        if (!Object.prototype.hasOwnProperty.call(data, 'cityCategoryKey') && cityId && categoryId) {
          update.cityCategoryKey = `${cityId}_${categoryId}`;
        }

        if (!Object.prototype.hasOwnProperty.call(data, 'dept') && postalCode) {
          const dept = deptFromPostal(postalCode);
          update.dept = dept || null;
        }

        if (!Object.prototype.hasOwnProperty.call(data, 'regionCode') && postalCode) {
          update.regionCode = inferRegionCodeFromPostalCode(postalCode);
        }

        if (!Object.prototype.hasOwnProperty.call(data, 'budgetValue')) {
          const rawBudget = data.budget;
          let n = null;
          if (typeof rawBudget === 'number') {
            n = rawBudget;
          } else if (typeof rawBudget === 'string') {
            const cleaned = rawBudget.trim().replace(/\s/g, '').replace(',', '.');
            const parsed = Number.parseFloat(cleaned);
            if (Number.isFinite(parsed)) n = parsed;
          }
          if (n != null) update.budgetValue = n;
        }

        if (Object.keys(update).length > 0) {
          update.updatedAt = FieldValue.serverTimestamp();
          totalPatched++;

          console.log(`  ✏️  ${doc.id}: ${Object.keys(update).join(', ')}`);

          if (!isDryRun) {
            batch.update(doc.ref, update);
          }

          batchWrites++;
          if (batchWrites >= 450) {
            await flush();
          }
        }
      }

      await flush();
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
    }

    if (totalScanned == 0) {
      console.log('❌ Aucune offre trouvée');
      return;
    }

    if (totalPatched == 0) {
      console.log('\n✅ Rien à backfiller (toutes les offres ont déjà isActive/status)');
      return;
    }

    console.log(
      `\n✅ Backfill terminé: ${totalPatched} doc(s) modifié(s), ${totalWrites} write(s)`
    );
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

// Si exécuté directement
if (import.meta.url === `file://${process.argv[1]}`) {
  fixAllOffers().then(() => {
    console.log('\n✨ Terminé');
    process.exit(0);
  }).catch(err => {
    console.error(err);
    process.exit(1);
  });
}

export { fixAllOffers };
