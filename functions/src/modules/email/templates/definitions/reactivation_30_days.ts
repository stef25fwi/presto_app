import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const reactivation30DaysTemplate = defineTemplate({
  id: "reactivation_30_days",
  templateCode: "tpl_marketing_reactivation_30_days_v1",
  category: "growth",
  type: "marketing",
  tone: "onboarding",
  goal: "Relancer les utilisateurs inactifs depuis 30 jours.",
  event: "growth.reactivation.30_days",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "dashboardUrl", type: "url", required: true, description: "Lien retour produit" },
  ],
  subject: "Revenez voir ce qui a evolue sur e-livre resto",
  previewText: "Votre espace est toujours pret. Reprenez votre activite quand vous voulez.",
  cta: { label: "Revenir sur mon espace", urlVariable: "dashboardUrl" },
  html: buildEmailHtml({
    title: "Votre espace vous attend",
    previewText: "Votre espace est toujours pret. Reprenez votre activite quand vous voulez.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Cela fait quelque temps que nous ne vous avons pas vu sur e-livre resto.",
      "Si vous souhaitez reprendre vos publications, vos echanges ou votre suivi d activite, votre espace est toujours disponible.",
    ],
    ctaLabel: "Revenir sur mon espace",
    ctaVariable: "dashboardUrl",
    tone: "onboarding",
    type: "marketing",
  }),
  text: buildEmailText({
    title: "Votre espace vous attend",
    previewText: "Votre espace est toujours pret. Reprenez votre activite quand vous voulez.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Votre espace e-livre resto est toujours disponible si vous souhaitez reprendre votre activite.",
    ],
    ctaLabel: "Revenir sur mon espace",
    ctaVariable: "dashboardUrl",
  }),
  rules: {
    trigger: "growth.reactivation.30_days",
    sendWhen: "Quand un utilisateur est inactif depuis 30 jours et reste eligible marketing.",
    skipWhen: ["Desabonnement marketing", "Compte supprime", "Activite recente"],
    unsubscribeAllowed: true,
    requiredPreferences: ["marketingEmailEnabled"],
    idempotencyScope: "userId + reactivation_30_days campaign",
  },
});