#!/usr/bin/env node
/**
 * Migration des comptes doublons vers le compte conservé (azertax).
 *
 * Pour chaque conversation/annonce rattachée à l'un des 6 uid doublons,
 * remplace cet uid par celui d'azertax (KEEP_UID) :
 *   - conversations : participantIds (+ alias), maps (participantNames,
 *     unreadCount, lastReadAt, archivedBy, blockedBy), lastSenderId, et
 *     senderId des messages ;
 *   - annonces : ownerId/advertiserId/userId/uid (listings, offers, listingDrafts).
 * Puis supprime les 6 docs users + comptes Auth (désormais vidés).
 *
 * azertax verra ainsi TOUTES les conversations consolidées.
 *
 * SÉCURITÉ : dry-run par défaut. Ajoute --apply pour exécuter.
 *   node tools/migrate_duplicates_to_azertax.cjs            # dry-run
 *   node tools/migrate_duplicates_to_azertax.cjs --apply    # migration réelle
 *   node tools/migrate_duplicates_to_azertax.cjs --apply --keep-accounts  # migre sans supprimer les comptes
 *
 * Auth : sa-key.json à la racine du repo SINON GOOGLE_APPLICATION_CREDENTIALS.
 */
const fs = require("fs");
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

// ---- Configuration -------------------------------------------------------
const KEEP_UID = "jyRmGHNVTvQF5QgjPbS2zpquiSY2"; // azertax — destination
const DUPLICATE_UIDS = [
  "CIExQfQ1gWbX9obuo6Mn",
  "LdQdbuNFgjgjXN0GMZwyAy1E0rq2",
  "OyVhJNFF8ryIHPLLBd9C",
  "S4IvRC4n2HQJ17UMFtlKb8sHQJ82",
  "aUPAjx1PvseHBJXBZZ4YOw6gwYh2",
  "y4d9ZdizRsK8eEYdIZkw",
];

const ARRAY_FIELDS = ["participantIds", "participants", "participant_ids", "userIds", "memberIds"];
const NUM_MAP_FIELDS = ["unreadCount", "unread_count"];
const STR_MAP_FIELDS = ["participantNames", "participant_names"];
const BOOL_MAP_FIELDS = ["archivedBy", "blockedBy"];
const UNKNOWN_MAP_FIELDS = ["lastReadAt", "last_read_at"];
const SENDER_FIELDS = ["lastSenderId", "last_sender_id"];
const MSG_SENDER_FIELDS = ["senderId", "sender_id"];
const OWNER_FIELDS = ["ownerId", "advertiserId", "userId", "uid"];
const LISTING_COLLECTIONS = ["listings", "offers", "listingDrafts"];
// --------------------------------------------------------------------------

const APPLY = process.argv.includes("--apply");
const KEEP_ACCOUNTS = process.argv.includes("--keep-accounts");
const DUP = new Set(DUPLICATE_UIDS);
const remap = (uid) => (DUP.has(String(uid)) ? KEEP_UID : uid);

const KEY_PATH = path.join(__dirname, "..", "sa-key.json");
if (fs.existsSync(KEY_PATH)) {
  admin.initializeApp({ credential: admin.credential.cert(KEY_PATH) });
} else {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}
const db = admin.firestore();
const auth = admin.auth();

if (DUP.has(KEEP_UID)) {
  console.error("❌ KEEP_UID figure dans DUPLICATE_UIDS. Abandon.");
  process.exit(1);
}

function remapArray(arr) {
  const out = Array.from(new Set(arr.map(remap).map((v) => String(v).trim()).filter(Boolean))).sort();
  return out;
}

// Remappe les clés d'une map uid->valeur. En cas de collision (D et K présents),
// garde la valeur "la plus forte" : max pour nombres, OR pour booléens, non-vide
// pour chaînes, valeur existante de K sinon celle de D pour le reste.
function remapMapKeys(map, kind) {
  const out = {};
  for (const [key, value] of Object.entries(map)) {
    const nk = String(remap(key)).trim();
    if (!nk) continue;
    if (!(nk in out)) {
      out[nk] = value;
      continue;
    }
    if (kind === "num") out[nk] = Math.max(Number(out[nk]) || 0, Number(value) || 0);
    else if (kind === "bool") out[nk] = out[nk] === true || value === true;
    else if (kind === "str") out[nk] = String(out[nk] || "").trim() || String(value || "").trim();
    // unknown: garde la valeur déjà présente (K prioritaire)
  }
  return out;
}

function mapChanged(before, after) {
  return JSON.stringify(before) !== JSON.stringify(after);
}

async function migrateConversations(stats) {
  const snap = await db.collection("conversations").get();
  let batch = db.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const patch = {};
    let touched = false;

    for (const f of ARRAY_FIELDS) {
      if (Array.isArray(data[f]) && data[f].some((v) => DUP.has(String(v)))) {
        patch[f] = remapArray(data[f]);
        touched = true;
      }
    }
    const mapGroups = [
      [STR_MAP_FIELDS, "str"],
      [NUM_MAP_FIELDS, "num"],
      [BOOL_MAP_FIELDS, "bool"],
      [UNKNOWN_MAP_FIELDS, "unknown"],
    ];
    for (const [fields, kind] of mapGroups) {
      for (const f of fields) {
        const m = data[f];
        if (m && typeof m === "object" && !Array.isArray(m) && Object.keys(m).some((k) => DUP.has(k))) {
          const remapped = remapMapKeys(m, kind);
          if (mapChanged(m, remapped)) {
            patch[f] = remapped;
            touched = true;
          }
        }
      }
    }
    for (const f of SENDER_FIELDS) {
      if (DUP.has(String(data[f]))) {
        patch[f] = KEEP_UID;
        touched = true;
      }
    }

    if (touched) {
      stats.conversations += 1;
      console.log(`   💬 conversations/${doc.id}`);
      if (APPLY) {
        batch.set(doc.ref, patch, { merge: true });
        pending += 1;
        if (pending >= 400) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }
    }

    // Messages : remap senderId
    const msgs = await doc.ref.collection("messages").get();
    for (const msg of msgs.docs) {
      const md = msg.data() || {};
      const mpatch = {};
      let mtouched = false;
      for (const f of MSG_SENDER_FIELDS) {
        if (DUP.has(String(md[f]))) {
          mpatch[f] = KEEP_UID;
          mtouched = true;
        }
      }
      if (mtouched) {
        stats.messages += 1;
        if (APPLY) {
          batch.set(msg.ref, mpatch, { merge: true });
          pending += 1;
          if (pending >= 400) {
            await batch.commit();
            batch = db.batch();
            pending = 0;
          }
        }
      }
    }
  }

  if (APPLY && pending > 0) await batch.commit();
}

async function migrateListings(stats) {
  for (const col of LISTING_COLLECTIONS) {
    for (const uid of DUPLICATE_UIDS) {
      for (const field of OWNER_FIELDS) {
        let qs;
        try {
          qs = await db.collection(col).where(field, "==", uid).get();
        } catch {
          continue;
        }
        for (const doc of qs.docs) {
          stats.listings += 1;
          console.log(`   📦 ${col}/${doc.id} (${field}: ${uid} -> ${KEEP_UID})`);
          if (APPLY) {
            await doc.ref.set({ [field]: KEEP_UID }, { merge: true });
          }
        }
      }
    }
  }
}

async function deleteDuplicateAccounts(stats) {
  for (const uid of DUPLICATE_UIDS) {
    console.log(`   🗑️ users/${uid} + Auth`);
    if (APPLY) {
      await db.recursiveDelete(db.collection("users").doc(uid));
      try {
        await auth.deleteUser(uid);
        stats.authDeleted += 1;
      } catch (e) {
        console.log(`      ⚠️ Auth non supprimé (${e.code || e.message})`);
      }
      stats.usersDeleted += 1;
    }
  }
}

async function main() {
  console.log("==================================================");
  console.log(APPLY ? "🔴 MIGRATION RÉELLE (--apply)" : "🟢 DRY-RUN (aucune écriture)");
  console.log("==================================================");
  console.log(`➡️  Destination (azertax) : ${KEEP_UID}`);
  console.log(`🔁 Comptes doublons à migrer : ${DUPLICATE_UIDS.length}`);
  console.log(KEEP_ACCOUNTS ? "ℹ️  Comptes doublons CONSERVÉS (--keep-accounts)" : "🗑️  Comptes doublons supprimés après migration");

  const stats = { conversations: 0, messages: 0, listings: 0, usersDeleted: 0, authDeleted: 0 };

  console.log("\n--- Conversations & messages ---");
  await migrateConversations(stats);
  console.log("\n--- Annonces ---");
  await migrateListings(stats);
  if (!KEEP_ACCOUNTS) {
    console.log("\n--- Suppression des comptes doublons ---");
    await deleteDuplicateAccounts(stats);
  }

  console.log("\n==================================================");
  console.log(APPLY ? "RÉSUMÉ MIGRATION" : "RÉSUMÉ DRY-RUN (rien écrit)");
  console.log("==================================================");
  console.log(`Conversations remappées : ${stats.conversations}`);
  console.log(`Messages remappés       : ${stats.messages}`);
  console.log(`Annonces transférées    : ${stats.listings}`);
  if (APPLY && !KEEP_ACCOUNTS) {
    console.log(`Docs users supprimés    : ${stats.usersDeleted}`);
    console.log(`Comptes Auth supprimés  : ${stats.authDeleted}`);
  }
  if (!APPLY) {
    console.log("\n👉 Vérifie la liste, puis relance avec --apply pour exécuter.");
  } else {
    console.log("\n✅ Migration terminée. azertax doit maintenant voir toutes les conversations.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Erreur:", e);
    process.exit(1);
  });
