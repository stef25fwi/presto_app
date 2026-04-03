import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const paymentConfirmedTemplate = defineTemplate({
  id: "payment_confirmed",
  templateCode: "tpl_transactional_payment_confirmed_v2",
  category: "billing",
  type: "transactional",
  tone: "trust",
  goal: "Confirmer un paiement abouti avec acces a la facture.",
  event: "billing.payment.succeeded",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "amount", type: "string", required: true, description: "Montant formate" },
    { key: "currency", type: "string", required: true, description: "Devise" },
    { key: "invoiceUrl", type: "url", required: true, description: "Lien facture" },
  ],
  subject: "Paiement confirme",
  previewText: "Votre paiement a bien ete pris en compte.",
  cta: { label: "Voir ma facture", urlVariable: "invoiceUrl" },
  html: buildEmailHtml({
    title: "Paiement confirme",
    previewText: "Votre paiement a bien ete pris en compte.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Nous confirmons la reception de votre paiement de <strong>{{amount}} {{currency}}</strong>.",
      "Vous pouvez recuperer votre justificatif depuis votre facture.",
    ],
    ctaLabel: "Voir ma facture",
    ctaVariable: "invoiceUrl",
    tone: "trust",
    type: "transactional",
  }),
  text: buildEmailText({
    title: "Paiement confirme",
    previewText: "Votre paiement a bien ete pris en compte.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Paiement confirme : {{amount}} {{currency}}.",
    ],
    ctaLabel: "Voir ma facture",
    ctaVariable: "invoiceUrl",
  }),
  rules: {
    trigger: "billing.payment.succeeded",
    sendWhen: "Quand un paiement est confirme par le PSP ou le backend billing.",
    skipWhen: ["Paiement rembourse avant emission"],
    unsubscribeAllowed: false,
    requiredPreferences: ["transactionalEmailEnabled"],
    idempotencyScope: "paymentId + success state",
  },
});