#!/usr/bin/env node

/**
 * Script pour corriger les offres dans Firestore.
 *
 * Objectif:
 * - Backfill des champs requis par l'app (ex: `isActive`) sur les anciennes annonces.
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

async function fixAllOffers() {
  console.log(
    `🔄 Backfill des offres (isActive/status)${isDryRun ? ' [DRY-RUN]' : ''}`
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
