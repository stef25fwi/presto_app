import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const listingRejectedTemplate = defineTemplate({
  id: "listing_rejected",
  templateCode: "tpl_transactional_listing_rejected_v2",
  category: "core_product",
  type: "transactional",
  tone: "security",
  goal: "Informer du refus d une annonce et guider vers correction ou support.",
  event: "listing.rejected",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "listingTitle", type: "string", required: true, description: "Titre de l annonce" },
    { key: "rejectionReason", type: "string", required: true, description: "Motif principal de refus" },
    { key: "editUrl", type: "url", required: true, description: "Lien de correction" },
  ],
  subject: "Votre annonce a besoin d ajustements",
  previewText: "Nous ne pouvons pas publier votre annonce en l etat. Voici ce qu il faut corriger.",
  cta: { label: "Corriger mon annonce", urlVariable: "editUrl" },
  html: buildEmailHtml({
    title: "Annonce a corriger",
    previewText: "Nous ne pouvons pas publier votre annonce en l etat. Voici ce qu il faut corriger.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Nous ne pouvons pas publier votre annonce <strong>{{listingTitle}}</strong> en l etat.",
      "Motif principal : {{rejectionReason}}.",
      "Apres correction, vous pourrez la soumettre a nouveau pour validation.",
    ],
    ctaLabel: "Corriger mon annonce",
    ctaVariable: "editUrl",
    tone: "security",
    type: "transactional",
  }),
  text: buildEmailText({
    title: "Annonce a corriger",
    previewText: "Nous ne pouvons pas publier votre annonce en l etat. Voici ce qu il faut corriger.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Votre annonce {{listingTitle}} ne peut pas etre publiee en l etat.",
      "Motif principal : {{rejectionReason}}.",
    ],
    ctaLabel: "Corriger mon annonce",
    ctaVariable: "editUrl",
  }),
  rules: {
    trigger: "listing.rejected",
    sendWhen: "Quand une annonce est refusee apres moderation.",
    skipWhen: ["Annonce supprimee", "Email deja emis pour le meme rejet"],
    unsubscribeAllowed: false,
    requiredPreferences: ["transactionalEmailEnabled"],
    idempotencyScope: "listingId + rejection version",
  },
});