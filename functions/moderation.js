const nodemailer = require('nodemailer');

function nowTs(admin) {
  return admin.firestore.FieldValue.serverTimestamp();
}

async function runModeration(text) {
  // Règles simples fallback (à remplacer par un provider OpenAI/Google si besoin)
  const forbidden = ["enculé", "pute", "nazi", "hitler", "viol", "tuer", "bombe"];
  const lowered = String(text || "").toLowerCase();
  const hit = forbidden.find((w) => lowered.includes(w));
  if (hit) {
    return {
      ok: false,
      provider: "rules-fallback",
      score: 0.99,
      categories: { forbidden_word: hit },
      reasonInternal: `Mot interdit détecté: ${hit}`,
      userMessage:
        "Votre annonce contient des termes non conformes aux CGU. Merci de reformuler avec un langage neutre et respectueux.",
    };
  }

  return { ok: true, provider: "rules-fallback", score: 0.01, categories: {} };
}

async function sendFlagEmail({ to, subject, text }) {
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || "587"),
    secure: false,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to,
    subject,
    text,
  });
}

async function notifyUser(admin, uid, payload) {
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .add({
      ...payload,
      createdAt: nowTs(admin),
      read: false,
    });
}

function createModerateNewOffer({ admin, onDocumentCreated, region = 'europe-west1' }) {
  return onDocumentCreated(
    { document: "offers/{offerId}", region },
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const offerId = event.params.offerId;
      const offer = snap.data() || {};
      const uid = offer.uid;
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
        { merge: true }
      );

      const content = `${offer.title || ""}\n\n${offer.description || ""}\n\n${offer.city || ""}`.trim();

      try {
        const res = await runModeration(content);

        if (res.ok) {
          await snap.ref.set(
            {
              moderation: {
                status: "APPROVED",
                checkedAt: nowTs(admin),
                provider: res.provider || "unknown",
                score: res.score ?? null,
                categories: res.categories || {},
                reason: null,
                userMessage: null,
              },
              visibility: {
                isPublic: true,
                publishedAt: nowTs(admin),
              },
            },
            { merge: true }
          );
          return;
        }

        // REJECT
        await snap.ref.set(
          {
            moderation: {
              status: "REJECTED",
              checkedAt: nowTs(admin),
              provider: res.provider || "unknown",
              score: res.score ?? null,
              categories: res.categories || {},
              reason: res.reasonInternal || "Non conforme",
              userMessage:
                res.userMessage ||
                "Votre annonce n’est pas conforme aux CGU. Merci de reformuler et de renvoyer.",
            },
            visibility: { isPublic: false, publishedAt: null },
          },
          { merge: true }
        );

        await notifyUser(admin, uid, {
          type: "OFFER_REJECTED",
          offerId,
          title: "Annonce à reformuler",
          message:
            res.userMessage ||
            "Votre annonce n’est pas conforme aux CGU. Merci de reformuler et de renvoyer.",
        });

        const to = process.env.FLAGGED_OFFERS_MAILBOX || "annonces-signalees@tondomaine.com";
        await sendFlagEmail({
          to,
          subject: `Annonce rejetée (${offerId}) - ${offer.title || "Sans titre"}`,
          text:
            `Annonce rejetée\n\n` +
            `offerId: ${offerId}\nuid: ${uid}\n\n` +
            `Titre: ${offer.title || ""}\nVille: ${offer.city || ""}\nPrix: ${offer.price || ""}\n\n` +
            `Raison: ${res.reasonInternal || "Non conforme"}\n` +
            `Catégories: ${JSON.stringify(res.categories || {}, null, 2)}\n\n` +
            `Contenu:\n${content}\n`,
        });
      } catch (e) {
        await snap.ref.set(
          {
            moderation: {
              status: "ERROR",
              checkedAt: nowTs(admin),
              provider: "unknown",
              reason: e?.message || "Erreur moderation",
              userMessage:
                "Votre annonce est en cours de vérification. Un délai supplémentaire est nécessaire. Réessayez plus tard.",
            },
            visibility: { isPublic: false, publishedAt: null },
          },
          { merge: true }
        );
      }
    }
  );
}

module.exports = {
  createModerateNewOffer,
};
