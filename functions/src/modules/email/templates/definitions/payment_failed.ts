import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const paymentFailedTemplate = defineTemplate({
  id: "payment_failed",
  templateCode: "tpl_transactional_payment_failed_v2",
  category: "billing",
  type: "transactional",
  tone: "security",
  goal: "Alerter sur un echec de paiement et pousser la relance securisee.",
  event: "billing.payment.failed",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "amount", type: "string", required: true, description: "Montant formate" },
    { key: "currency", type: "string", required: true, description: "Devise" },
    { key: "retryUrl", type: "url", required: true, description: "Lien de regularisation" },
    { key: "nextRetryDate", type: "date", required: false, description: "Date de nouvelle tentative" },
  ],
  subject: "Votre paiement n a pas abouti",
  previewText: "Regularisez votre paiement pour eviter une interruption de service.",
  cta: { label: "Mettre a jour mon paiement", urlVariable: "retryUrl" },
  html: buildEmailHtml({
    title: "Paiement echoue",
    previewText: "Regularisez votre paiement pour eviter une interruption de service.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Nous n avons pas pu finaliser le paiement de <strong>{{amount}} {{currency}}</strong>.",
      "Prochaine tentative eventuelle : {{nextRetryDate}}.",
      "Merci de mettre a jour votre moyen de paiement pour eviter une interruption de service.",
    ],
    ctaLabel: "Mettre a jour mon paiement",
    ctaVariable: "retryUrl",
    tone: "security",
    type: "transactional",
  }),
  text: buildEmailText({
    title: "Paiement echoue",
    previewText: "Regularisez votre paiement pour eviter une interruption de service.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Le paiement de {{amount}} {{currency}} n a pas abouti.",
      "Prochaine tentative eventuelle : {{nextRetryDate}}.",
    ],
    ctaLabel: "Mettre a jour mon paiement",
    ctaVariable: "retryUrl",
  }),
  rules: {
    trigger: "billing.payment.failed",
    sendWhen: "Quand un paiement est refuse ou echoue.",
    skipWhen: ["Paiement deja regularise"],
    unsubscribeAllowed: false,
    requiredPreferences: ["transactionalEmailEnabled"],
    idempotencyScope: "paymentId + failure state",
  },
});