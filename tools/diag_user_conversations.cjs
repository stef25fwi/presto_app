#!/usr/bin/env node
/**
 * Diagnostic : pourquoi un utilisateur ne voit pas ses conversations.
 *
 * Usage :
 *   node tools/diag_user_conversations.cjs krys           # recherche par nom/email
 *   node tools/diag_user_conversations.cjs <uid>          # diagnostic direct par UID
 *
 * Nécessite ./sa-key.json (jamais commitée).
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

const KEY_PATH = path.join(__dirname, "..", "sa-key.json");
const ARG = (process.argv[2] || "").trim();

const ALIASES = [
  "participantIds",
  "participants",
  "participant_ids",
  "userIds",
  "memberIds",
];

admin.initializeApp({ credential: admin.credential.cert(KEY_PATH) });
const db = admin.firestore();

async function resolveUser(arg) {
  // Tente d'abord comme UID direct
  const direct = await db.collection("users").doc(arg).get();
  if (direct.exists) {
    return [{ uid: direct.id, ...direct.data() }];
  }
  // Sinon recherche par nom/email (insensible à la casse, contient)
  const snap = await db.collection("users").get();
  const needle = arg.toLowerCase();
  return snap.docs
    .map((d) => ({ uid: d.id, ...d.data() }))
    .filter((u) => {
      const hay = [
        u.displayName,
        u.name,
        u.firstName,
        u.lastName,
        u.email,
        u.pseudo,
        u.username,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return hay.includes(needle);
    });
}

async function diagnoseUid(uid, label) {
  console.log("\n========================================");
  console.log(`👤 ${label}`);
  console.log(`   UID: ${uid}`);
  console.log("========================================");

  const matchedIds = new Set();
  const matchedByField = {};

  for (const field of ALIASES) {
    let count = 0;
    try {
      const snap = await db
        .collection("conversations")
        .where(field, "array-contains", uid)
        .get();
      count = snap.size;
      snap.docs.forEach((d) => matchedIds.add(d.id));
    } catch (e) {
      console.log(`   ⚠️  Requête sur '${field}' a échoué: ${e.message}`);
    }
    matchedByField[field] = count;
  }

  console.log("\n📊 Conversations trouvées par champ (requête array-contains):");
  for (const field of ALIASES) {
    console.log(`   ${field.padEnd(16)} : ${matchedByField[field]}`);
  }
  console.log(`   → Total unique          : ${matchedIds.size}`);

  // Recherche les conversations « orphelines » : où l'utilisateur apparaît
  // dans participantNames/unreadCount mais PAS dans participantIds.
  console.log("\n🔎 Recherche d'incohérences de données…");
  const allConvs = await db.collection("conversations").get();
  let orphanInNames = 0;
  let archivedCount = 0;
  const orphanSamples = [];

  allConvs.docs.forEach((d) => {
    const data = d.data();
    const inIdArrays = ALIASES.some(
      (f) => Array.isArray(data[f]) && data[f].includes(uid)
    );
    const inNameMap =
      (data.participantNames && uid in data.participantNames) ||
      (data.participant_names && uid in data.participant_names) ||
      (data.unreadCount && uid in data.unreadCount);

    if (inNameMap && !inIdArrays) {
      orphanInNames += 1;
      if (orphanSamples.length < 5) {
        orphanSamples.push({
          id: d.id,
          participantIds: data.participantIds || data.participants || null,
          names: Object.keys(data.participantNames || data.participant_names || {}),
        });
      }
    }

    if (inIdArrays) {
      const archived =
        (data.archivedBy && data.archivedBy[uid] === true) ||
        (data.archived_by && data.archived_by[uid] === true);
      if (archived) archivedCount += 1;
    }
  });

  console.log(`   Conversations totales en base       : ${allConvs.size}`);
  console.log(`   Archivées pour cet utilisateur      : ${archivedCount}`);
  console.log(`   ⚠️  Orphelines (dans names mais PAS dans participantIds): ${orphanInNames}`);

  if (orphanSamples.length) {
    console.log("\n   Exemples d'orphelines (BUG probable) :");
    orphanSamples.forEach((s) => {
      console.log(`     - ${s.id}`);
      console.log(`         participantIds: ${JSON.stringify(s.participantIds)}`);
      console.log(`         participantNames keys: ${JSON.stringify(s.names)}`);
    });
  }

  // Verdict
  console.log("\n🩺 Verdict :");
  if (matchedIds.size === 0 && orphanInNames > 0) {
    console.log("   ❌ BUG: l'utilisateur a des conversations où son nom apparaît,");
    console.log("      mais son UID est ABSENT de participantIds → requête renvoie 0.");
    console.log("      => Réparation des champs participantIds nécessaire.");
  } else if (matchedIds.size > 0 && archivedCount === matchedIds.size) {
    console.log("   ⚠️  Toutes ses conversations sont ARCHIVÉES → masquées dans l'onglet par défaut.");
  } else if (matchedIds.size > 0) {
    console.log(`   ✅ ${matchedIds.size} conversation(s) devraient s'afficher (dont ${archivedCount} archivée(s)).`);
    console.log("      Si l'app affiche 0 → vérifier App Check / index Firestore / règles.");
  } else {
    console.log("   ℹ️  Aucune conversation trouvée pour cet utilisateur (ni orpheline).");
    console.log("      L'utilisateur n'a peut-être réellement aucune conversation.");
  }
}

async function main() {
  if (!ARG) {
    console.log("Usage: node tools/diag_user_conversations.cjs <nom|email|uid>");
    process.exit(1);
  }
  const users = await resolveUser(ARG);
  if (users.length === 0) {
    console.log(`❌ Aucun utilisateur correspondant à « ${ARG} ».`);
    process.exit(0);
  }
  if (users.length > 5) {
    console.log(`⚠️  ${users.length} utilisateurs correspondent à « ${ARG} ». Précise l'UID :`);
    users.slice(0, 20).forEach((u) =>
      console.log(`   ${u.uid}  ${u.displayName || u.name || ""}  ${u.email || ""}`)
    );
    process.exit(0);
  }
  for (const u of users) {
    const label = `${u.displayName || u.name || "?"}  <${u.email || "sans email"}>`;
    await diagnoseUid(u.uid, label);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Erreur:", e.message);
    process.exit(1);
  });
