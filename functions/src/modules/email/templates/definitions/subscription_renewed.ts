import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const subscriptionRenewedTemplate = defineTemplate({
  id: "subscription_renewed",
  templateCode: "tpl_transactional_subscription_renewed_v1",
  category: "billing",
  type: "transactional",
  tone: "trust",
  goal: "Confirmer un renouvellement d abonnement reussi.",
  event: "billing.subscription.renewed",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "planName", type: "string", required: true, description: "Nom du plan" },
    { key: "renewalDate", type: "date", required: true, description: "Date de renouvellement" },
    { key: "manageUrl", type: "url", required: true, description: "Lien de gestion" },
  ],
  subject: "Votre abonnement a ete renouvele",
  previewText: "Votre plan reste actif sans interruption.",
  cta: { label: "Gerer mon abonnement", urlVariable: "manageUrl" },
  html: buildEmailHtml({
    title: "Abonnement renouvele",
    previewText: "Votre plan reste actif sans interruption.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Votre abonnement <strong>{{planName}}</strong> a ete renouvele avec succes le {{renewalDate}}.",
      "Votre acces aux fonctionnalites associees reste actif sans interruption.",
    ],
    ctaLabel: "Gerer mon abonnement",
    ctaVariable: "manageUrl",
    tone: "trust",
    type: "transactional",
  }),
  text: buildEmailText({
    title: "Abonnement renouvele",
    previewText: "Votre plan reste actif sans interruption.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Votre abonnement {{planName}} a ete renouvele le {{renewalDate}}.",
    ],
    ctaLabel: "Gerer mon abonnement",
    ctaVariable: "manageUrl",
  }),
  rules: {
    trigger: "billing.subscription.renewed",
    sendWhen: "Quand un abonnement est renouvele avec succes.",
    skipWhen: ["Abonnement annule avant emission"],
    unsubscribeAllowed: false,
    requiredPreferences: ["transactionalEmailEnabled"],
    idempotencyScope: "subscriptionId + renewalDate",
  },
});