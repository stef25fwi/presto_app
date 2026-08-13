#!/usr/bin/env node
/**
 * Suppression contrôlée de comptes doublons.
 *
 * Conserve UNIQUEMENT le compte gardé (KEEP_UID) et supprime, pour chaque
 * compte à effacer (DELETE_UIDS) :
 *   - ses annonces (listings + legacy offers + listingDrafts)
 *   - ses conversations (conversations + sous-collection messages)
 *   - son document users/{uid}
 *   - son compte Firebase Auth
 *
 * SÉCURITÉ : dry-run par défaut. Ajoute --apply pour exécuter réellement.
 * Les UID ne doivent jamais être stockés dans le dépôt : fournis-les par
 * variables d'environnement au moment de l'exécution.
 *
 * Usage :
 *   KEEP_UID="uid-a-conserver" DELETE_UIDS="uid-1,uid-2" \
 *     node tools/delete_duplicate_accounts.cjs
 *
 *   KEEP_UID="uid-a-conserver" DELETE_UIDS="uid-1,uid-2" \
 *     node tools/delete_duplicate_accounts.cjs --apply
 *
 * Auth : sa-key.json à la racine du repo SINON GOOGLE_APPLICATION_CREDENTIALS.
 */
const fs = require("fs");
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

// ---- Configuration -------------------------------------------------------
const KEEP_UID = String(process.env.KEEP_UID || "").trim();
const DELETE_UIDS = String(process.env.DELETE_UIDS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);

if (!KEEP_UID || DELETE_UIDS.length === 0) {
  console.error(
    "❌ Configuration manquante. Définis KEEP_UID et DELETE_UIDS (liste séparée par des virgules).",
  );
  process.exit(1);
}

const PARTICIPANT_ALIASES = [
  "participantIds",
  "participants",
  "participant_ids",
  "userIds",
  "memberIds",
];
const OWNER_FIELDS = ["ownerId", "advertiserId", "userId", "uid"];
const LISTING_COLLECTIONS = ["listings", "offers", "listingDrafts"];
// --------------------------------------------------------------------------

const APPLY = process.argv.includes("--apply");
const KEY_PATH = path.join(__dirname, "..", "sa-key.json");

if (fs.existsSync(KEY_PATH)) {
  admin.initializeApp({ credential: admin.credential.cert(KEY_PATH) });
} else {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}
const db = admin.firestore();
const auth = admin.auth();

if (DELETE_UIDS.includes(KEEP_UID)) {
  console.error("❌ KEEP_UID figure dans DELETE_UIDS. Abandon.");
  process.exit(1);
}

if (new Set(DELETE_UIDS).size !== DELETE_UIDS.length) {
  console.error("❌ DELETE_UIDS contient des doublons. Abandon.");
  process.exit(1);
}

async function findListings(uid) {
  const found = new Map(); // collection/id -> ref
  for (const col of LISTING_COLLECTIONS) {
    for (const field of OWNER_FIELDS) {
      let snap;
      try {
        snap = await db.collection(col).where(field, "==", uid).get();
      } catch (e) {
        continue;
      }
      snap.docs.forEach((d) => found.set(`${col}/${d.id}`, d.ref));
    }
  }
  return found;
}

async function findConversations(uid) {
  const found = new Map(); // id -> {ref, involvesKeep}
  for (const field of PARTICIPANT_ALIASES) {
    let snap;
    try {
      snap = await db.collection("conversations").where(field, "array-contains", uid).get();
    } catch (e) {
      continue;
    }
    snap.docs.forEach((d) => {
      const data = d.data();
      const allParticipants = new Set();
      for (const f of PARTICIPANT_ALIASES) {
        if (Array.isArray(data[f])) data[f].forEach((p) => allParticipants.add(p));
      }
      found.set(d.id, {
        ref: d.ref,
        involvesKeep: allParticipants.has(KEEP_UID),
      });
    });
  }
  return found;
}

async function main() {
  console.log("==================================================");
  console.log(APPLY ? "🔴 MODE SUPPRESSION RÉELLE (--apply)" : "🟢 DRY-RUN (aucune écriture)");
  console.log("==================================================");
  console.log(`✅ Compte CONSERVÉ : ${KEEP_UID}`);
  console.log(`🗑️  Comptes à supprimer : ${DELETE_UIDS.length}`);

  const totals = { listings: 0, conversations: 0, conversationsWithKeep: 0, users: 0, authDeleted: 0 };

  for (const uid of DELETE_UIDS) {
    console.log("\n--------------------------------------------------");
    console.log(`👤 UID : ${uid}`);

    // 1. Annonces
    const listings = await findListings(uid);
    console.log(`   📦 Annonces rattachées : ${listings.size}`);
    for (const key of listings.keys()) console.log(`      - ${key}`);

    // 2. Conversations
    const conversations = await findConversations(uid);
    console.log(`   💬 Conversations rattachées : ${conversations.size}`);
    for (const [id, info] of conversations) {
      console.log(`      - conversations/${id}${info.involvesKeep ? "  ⚠️ (implique aussi le compte conservé)" : ""}`);
      if (info.involvesKeep) totals.conversationsWithKeep += 1;
    }

    totals.listings += listings.size;
    totals.conversations += conversations.size;
    totals.users += 1;

    if (APPLY) {
      for (const ref of listings.values()) {
        await db.recursiveDelete(ref);
      }
      for (const info of conversations.values()) {
        await db.recursiveDelete(info.ref);
      }
      await db.recursiveDelete(db.collection("users").doc(uid));
      try {
        await auth.deleteUser(uid);
        totals.authDeleted += 1;
        console.log("   ✅ Compte Auth supprimé.");
      } catch (e) {
        console.log(`   ⚠️ Auth non supprimé (${e.code || e.message}).`);
      }
      console.log("   ✅ Données Firestore supprimées.");
    }
  }

  console.log("\n==================================================");
  console.log(APPLY ? "RÉSUMÉ SUPPRESSION" : "RÉSUMÉ DRY-RUN (rien supprimé)");
  console.log("==================================================");
  console.log(`Annonces        : ${totals.listings}`);
  console.log(`Conversations   : ${totals.conversations}  (dont ${totals.conversationsWithKeep} impliquant aussi le compte conservé)`);
  console.log(`Docs users      : ${totals.users}`);
  if (APPLY) console.log(`Comptes Auth    : ${totals.authDeleted}`);
  if (!APPLY) {
    console.log("\n👉 Vérifie la liste ci-dessus, puis relance avec --apply pour supprimer réellement.");
  }
  if (totals.conversationsWithKeep > 0 && !APPLY) {
    console.log(`\n⚠️  ${totals.conversationsWithKeep} conversation(s) impliquent AUSSI le compte conservé`);
    console.log("   et seront supprimées car rattachées à un compte doublon.");
    console.log("   Vérifie ce point avant de relancer avec --apply.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Erreur:", e);
    process.exit(1);
  });