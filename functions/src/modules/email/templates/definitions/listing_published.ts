import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const listingPublishedTemplate = defineTemplate({
  id: "listing_published",
  templateCode: "tpl_transactional_listing_published_v2",
  category: "core_product",
  type: "transactional",
  tone: "trust",
  goal: "Confirmer la mise en ligne d une annonce.",
  event: "listing.published",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "listingTitle", type: "string", required: true, description: "Titre de l annonce" },
    { key: "listingUrl", type: "url", required: true, description: "Lien public ou prive de l annonce" },
  ],
  subject: "Votre annonce est en ligne",
  previewText: "Votre annonce est maintenant visible. Vous pouvez commencer a recevoir des contacts.",
  cta: { label: "Voir mon annonce", urlVariable: "listingUrl" },
  html: buildEmailHtml({
    title: "Annonce publiee",
    previewText: "Votre annonce est maintenant visible. Vous pouvez commencer a recevoir des contacts.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Bonne nouvelle : votre annonce <strong>{{listingTitle}}</strong> est maintenant publiee.",
      "Elle peut desormais etre consultee par les personnes concernees et generer des prises de contact.",
    ],
    ctaLabel: "Voir mon annonce",
    ctaVariable: "listingUrl",
    tone: "trust",
    type: "transactional",
  }),
  text: buildEmailText({
    title: "Annonce publiee",
    previewText: "Votre annonce est maintenant visible. Vous pouvez commencer a recevoir des contacts.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Votre annonce {{listingTitle}} est maintenant publiee.",
    ],
    ctaLabel: "Voir mon annonce",
    ctaVariable: "listingUrl",
  }),
  rules: {
    trigger: "listing.published",
    sendWhen: "Quand une annonce passe en statut publie.",
    skipWhen: ["Annonce retiree avant envoi"],
    unsubscribeAllowed: false,
    requiredPreferences: ["transactionalEmailEnabled"],
    idempotencyScope: "listingId + published_at",
  },
});