#!/usr/bin/env node
/**
 * P0-1 (nettoyage) — Supprime le numéro de téléphone des annonces déjà
 * publiées dont le propriétaire a choisi de le masquer (hidePhone == true).
 *
 * Le correctif code empêche les NOUVELLES fuites ; ce script traite les
 * annonces existantes créées avant le déploiement.
 *
 * Collections scannées : listings + offers (legacy).
 * Action : si hidePhone==true et qu'un phone non vide est présent, on met
 *          phone = null (le document public ne contient plus le numéro).
 *
 * SÉCURITÉ : dry-run par défaut. Ajoute --apply pour exécuter.
 *   node tools/cleanup_hidden_phones.cjs            # dry-run
 *   node tools/cleanup_hidden_phones.cjs --apply    # nettoyage réel
 *
 * Auth : sa-key.json à la racine du repo SINON GOOGLE_APPLICATION_CREDENTIALS.
 */
const fs = require("fs");
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

const COLLECTIONS = ["listings", "offers"];
const PHONE_FIELDS = ["phone", "phoneNumber", "phone_number", "telephone"];

const APPLY = process.argv.includes("--apply");
const KEY_PATH = path.join(__dirname, "..", "sa-key.json");

if (fs.existsSync(KEY_PATH)) {
  admin.initializeApp({ credential: admin.credential.cert(KEY_PATH) });
} else {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}
const db = admin.firestore();

function isHidden(data) {
  return data.hidePhone === true || String(data.hidePhone).trim() === "true";
}

function hasPhone(data) {
  return PHONE_FIELDS.some((f) => {
    const v = data[f];
    return v !== undefined && v !== null && String(v).trim() !== "";
  });
}

async function main() {
  console.log("==================================================");
  console.log(APPLY ? "🔴 NETTOYAGE RÉEL (--apply)" : "🟢 DRY-RUN (aucune écriture)");
  console.log("==================================================");

  const stats = { scanned: 0, hidden: 0, cleaned: 0 };
  let batch = db.batch();
  let pending = 0;

  for (const col of COLLECTIONS) {
    let snap;
    try {
      snap = await db.collection(col).get();
    } catch (e) {
      console.log(`⚠️ Collection ${col} illisible: ${e.message}`);
      continue;
    }
    console.log(`\n--- ${col} : ${snap.size} document(s) ---`);

    for (const doc of snap.docs) {
      stats.scanned += 1;
      const data = doc.data() || {};
      if (!isHidden(data)) continue;
      stats.hidden += 1;
      if (!hasPhone(data)) continue;

      stats.cleaned += 1;
      console.log(`   🧹 ${col}/${doc.id} (hidePhone=true, numéro présent -> null)`);

      if (APPLY) {
        const patch = {};
        for (const f of PHONE_FIELDS) {
          if (data[f] !== undefined && data[f] !== null && String(data[f]).trim() !== "") {
            patch[f] = null;
          }
        }
        batch.set(doc.ref, patch, { merge: true });
        pending += 1;
        if (pending >= 400) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }
    }
  }

  if (APPLY && pending > 0) await batch.commit();

  console.log("\n==================================================");
  console.log(APPLY ? "RÉSUMÉ NETTOYAGE" : "RÉSUMÉ DRY-RUN (rien écrit)");
  console.log("==================================================");
  console.log(`Documents scannés          : ${stats.scanned}`);
  console.log(`Avec hidePhone=true        : ${stats.hidden}`);
  console.log(`Numéros ${APPLY ? "supprimés" : "à supprimer"}        : ${stats.cleaned}`);
  if (!APPLY) {
    console.log("\n👉 Vérifie la liste, puis relance avec --apply pour nettoyer réellement.");
  } else {
    console.log("\n✅ Nettoyage terminé. Les annonces masquées ne contiennent plus de numéro.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Erreur:", e);
    process.exit(1);
  });
