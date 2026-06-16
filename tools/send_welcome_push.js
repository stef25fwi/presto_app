#!/usr/bin/env node
/**
 * Envoi d'une notification push de bienvenue à tous les utilisateurs
 * ayant un token FCM actif.
 *
 * Usage :
 *   node tools/send_welcome_push.js            # envoi réel à tous
 *   node tools/send_welcome_push.js --dry-run  # compte les tokens sans envoyer
 *
 * Nécessite ./sa-key.json (clé de service Firebase, jamais commitée).
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

const KEY_PATH = path.join(__dirname, "..", "sa-key.json");
const DRY_RUN = process.argv.includes("--dry-run");

const TITLE = "Bienvenue sur iliprestō 👋";
const BODY =
  "Vos notifications sont activées ! Vous serez prévenu dès qu'un message ou une offre vous concerne.";

admin.initializeApp({ credential: admin.credential.cert(KEY_PATH) });
const db = admin.firestore();

async function main() {
  console.log("⏳ Collecte des tokens push…");
  const usersSnap = await db.collection("users").get();
  const tokens = []; // { uid, docId, token }

  for (const userDoc of usersSnap.docs) {
    const tk = await userDoc.ref.collection("push_tokens").get();
    tk.forEach((d) => {
      const data = d.data();
      const token = String(data.token || "").trim();
      if (token && data.enabled !== false) {
        tokens.push({ uid: userDoc.id, docId: d.id, token });
      }
    });
  }

  console.log(
    `📱 Tokens trouvés: ${tokens.length} (sur ${usersSnap.size} utilisateurs)`
  );

  if (tokens.length === 0) {
    console.log("❌ Aucun token — personne n'a encore activé les notifications.");
    return;
  }

  if (DRY_RUN) {
    console.log("🧪 --dry-run : aucun envoi effectué.");
    return;
  }

  let success = 0;
  let failure = 0;
  const invalid = []; // { uid, docId }

  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const res = await admin.messaging().sendEachForMulticast({
      tokens: batch.map((t) => t.token),
      notification: { title: TITLE, body: BODY },
      webpush: {
        notification: {
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
        },
        fcmOptions: { link: "https://ilipresto.web.app" },
      },
      android: {
        priority: "high",
        notification: { channelId: "ilipresto_activity", sound: "default" },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      },
    });

    success += res.successCount;
    failure += res.failureCount;

    res.responses.forEach((r, idx) => {
      if (r.success) return;
      const code = (r.error && r.error.code) || "";
      if (
        code.indexOf("registration-token-not-registered") !== -1 ||
        code.indexOf("invalid-registration-token") !== -1
      ) {
        invalid.push(batch[idx]);
      } else {
        console.log(`  ⚠️  ${code} - ${batch[idx].token.slice(0, 20)}…`);
      }
    });
  }

  console.log("");
  console.log(`✅ Succès : ${success}`);
  console.log(`❌ Échecs : ${failure}`);

  if (invalid.length) {
    const wb = db.batch();
    invalid.forEach((t) =>
      wb.delete(
        db.collection("users").doc(t.uid).collection("push_tokens").doc(t.docId)
      )
    );
    await wb.commit();
    console.log(`🧹 Tokens invalides supprimés : ${invalid.length}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Erreur:", e.message);
    process.exit(1);
  });
