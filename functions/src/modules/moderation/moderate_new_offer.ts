import { onDocumentCreated } from "firebase-functions/v2/firestore";
import admin from "../../core/firebase_admin_compat";
import * as nodemailer from "nodemailer";
import { PROJECT_REGION } from "../../config/env";

// ── Helpers ───────────────────────────────────────────────────────────────────

function nowTs() {
  return admin.firestore.FieldValue.serverTimestamp();
}

const FORBIDDEN_WORDS = [
  "enculé", "pute", "nazi", "hitler", "viol", "tuer", "bombe",
];

function runModeration(text: string) {
  const lowered = String(text || "").toLowerCase();
  const hit = FORBIDDEN_WORDS.find((w) => lowered.includes(w));
  if (hit) {
    return {
      ok: false as const,
      provider: "rules-fallback",
      score: 0.99,
      categories: { forbidden_word: hit },
      reasonInternal: `Mot interdit détecté: ${hit}`,
      userMessage:
        "Votre annonce contient des termes non conformes aux CGU. Merci de reformuler avec un langage neutre et respectueux.",
    };
  }
  return {
    ok: true as const,
    provider: "rules-fallback",
    score: 0.01,
    categories: {} as Record<string, string>,
  };
}

async function sendFlagEmail(opts: { to: string; subject: string; text: string }) {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM;
  if (!host || !user || !pass || !from) {
    console.error("[moderation] SMTP credentials manquants (SMTP_HOST, SMTP_USER, SMTP_PASS, SMTP_FROM) — email admin non envoyé");
    throw new Error("SMTP not configured");
  }
  const transporter = nodemailer.createTransport({
    host,
    port: Number(process.env.SMTP_PORT || "587"),
    secure: false,
    auth: { user, pass },
  });
  await transporter.sendMail({ from, to: opts.to, subject: opts.subject, text: opts.text });
}

async function notifyUser(uid: string, payload: Record<string, unknown>) {
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .add({ ...payload, createdAt: nowTs(), read: false });
}

// ── Trigger ───────────────────────────────────────────────────────────────────

export const moderateNewOffer = onDocumentCreated(
  { document: "offers/{offerId}", region: PROJECT_REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const offerId = event.params.offerId;
    const offer = snap.data() || ({} as Record<string, unknown>);
    const uid = (offer.uid || offer.userId) as string | undefined;
    if (!uid) return;

    // Force un état safe dès la création
    await snap.ref.set(
      {
        moderation: {
          status: "PENDING",
          checkedAt: null,
          provider: null,
          score: null,
          categories: {},
          reason: null,
          userMessage: null,
        },
        visibility: { isPublic: false, publishedAt: null },
      },
      { merge: true },
    );

    const content = `${offer.title || ""}\n\n${offer.description || ""}\n\n${offer.city || ""}`.trim();

    try {
      const res = runModeration(content);

      if (res.ok) {
        await snap.ref.set(
          {
            moderation: {
              status: "APPROVED",
              checkedAt: nowTs(),
              provider: res.provider,
              score: res.score,
              categories: res.categories,
              reason: null,
              userMessage: null,
            },
            visibility: { isPublic: true, publishedAt: nowTs() },
          },
          { merge: true },
        );

        // Notifications favoris
        try {
          const category = (offer.category as string) || null;
          const subCategory = (offer.subCategory as string) || null;
          const title = (offer.title as string) || "";

          if (category) {
            const usersQuery = await admin
              .firestore()
              .collection("users")
              .where("favoriteCategories", "array-contains", category)
              .get();

            const batch = admin.firestore().batch();
            const now = admin.firestore.Timestamp.now();

            for (const userDoc of usersQuery.docs) {
              if (userDoc.id === uid) continue;

              const userData = userDoc.data() || {};
              const selectedCats = Array.isArray(userData.selectedFavoriteCategories)
                ? userData.selectedFavoriteCategories.map(String)
                : [];
              const selectedSubcats = Array.isArray(userData.selectedFavoriteSubcategories)
                ? userData.selectedFavoriteSubcategories.map(String)
                : [];

              let shouldNotify = selectedCats.includes(String(category));
              if (subCategory) {
                shouldNotify =
                  shouldNotify && (selectedSubcats.length === 0 || selectedSubcats.includes(String(subCategory)));
              }
              if (!shouldNotify) continue;

              const notifRef = admin.firestore().collection("notifications").doc();
              batch.set(notifRef, {
                userId: userDoc.id,
                offerId,
                title: `Nouvelle annonce en ${category} !`,
                message: "Une offre correspond à tes favoris. Regarde vite.",
                category,
                subCategory,
                read: false,
                createdAt: now,
              });
            }

            await batch.commit();
          }
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e);
          console.warn("[moderation] Notifications favoris échouées", { offerId, uid, message: msg });
        }
        return;
      }

      // REJECT
      await snap.ref.set(
        {
          moderation: {
            status: "REJECTED",
            checkedAt: nowTs(),
            provider: res.provider,
            score: res.score,
            categories: res.categories,
            reason: res.reasonInternal || "Non conforme",
            userMessage:
              res.userMessage ||
              "Votre annonce n'est pas conforme aux CGU. Merci de reformuler et de renvoyer.",
          },
          visibility: { isPublic: false, publishedAt: null },
        },
        { merge: true },
      );

      await notifyUser(uid, {
        type: "OFFER_REJECTED",
        offerId,
        title: "Annonce à reformuler",
        message:
          res.userMessage ||
          "Votre annonce n'est pas conforme aux CGU. Merci de reformuler et de renvoyer.",
      });

      const to = process.env.FLAGGED_OFFERS_MAILBOX;
      if (!to) {
        console.error("[moderation] FLAGGED_OFFERS_MAILBOX env var not set — skipping admin alert email", { offerId, uid });
        return;
      }
      try {
        await sendFlagEmail({
          to,
          subject: `Annonce rejetée (${offerId}) - ${offer.title || "Sans titre"}`,
          text: [
            "Annonce rejetée",
            "",
            `offerId: ${offerId}`,
            `uid: ${uid}`,
            "",
            `Titre: ${offer.title || ""}`,
            `Ville: ${offer.city || ""}`,
            `Prix: ${offer.price || ""}`,
            "",
            `Raison: ${res.reasonInternal || "Non conforme"}`,
            `Catégories: ${JSON.stringify(res.categories || {}, null, 2)}`,
            "",
            `Contenu:\n${content}`,
          ].join("\n"),
        });
      } catch (emailErr: unknown) {
        const msg = emailErr instanceof Error ? emailErr.message : String(emailErr);
        console.warn("[moderation] Email flagged offers échoué", { offerId, uid, message: msg });
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      await snap.ref.set(
        {
          moderation: {
            status: "ERROR",
            checkedAt: nowTs(),
            provider: "unknown",
            reason: msg || "Erreur moderation",
            userMessage:
              "Votre annonce est en cours de vérification. Un délai supplémentaire est nécessaire. Réessayez plus tard.",
          },
          visibility: { isPublic: false, publishedAt: null },
        },
        { merge: true },
      );
    }
  },
);
