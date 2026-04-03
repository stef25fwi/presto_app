import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const nearbyNewListingsTemplate = defineTemplate({
  id: "nearby_new_listings",
  templateCode: "tpl_marketing_nearby_new_listings_v1",
  category: "growth",
  type: "marketing",
  tone: "trust",
  goal: "Notifier les nouvelles opportunites locales pertinentes.",
  event: "growth.nearby_new_listings",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "city", type: "string", required: true, description: "Ville cible" },
    { key: "matchCount", type: "number", required: true, description: "Nombre d annonces pertinentes" },
    { key: "resultsUrl", type: "url", required: true, description: "Lien vers les resultats" },
  ],
  subject: "De nouvelles annonces pres de {{city}}",
  previewText: "Consultez les nouvelles opportunites publiees pres de chez vous.",
  cta: { label: "Voir les annonces", urlVariable: "resultsUrl" },
  html: buildEmailHtml({
    title: "Nouvelles annonces proches de vous",
    previewText: "Consultez les nouvelles opportunites publiees pres de chez vous.",
    intro: "Bonjour {{firstName}},",
    body: [
      "{{matchCount}} nouvelles annonces susceptibles de vous interesser ont ete publiees pres de {{city}}.",
      "Consultez la selection pour identifier rapidement celles qui correspondent a vos besoins.",
    ],
    ctaLabel: "Voir les annonces",
    ctaVariable: "resultsUrl",
    tone: "trust",
    type: "marketing",
  }),
  text: buildEmailText({
    title: "Nouvelles annonces proches de vous",
    previewText: "Consultez les nouvelles opportunites publiees pres de chez vous.",
    intro: "Bonjour {{firstName}},",
    body: [
      "{{matchCount}} nouvelles annonces ont ete publiees pres de {{city}}.",
    ],
    ctaLabel: "Voir les annonces",
    ctaVariable: "resultsUrl",
  }),
  rules: {
    trigger: "growth.nearby_new_listings",
    sendWhen: "Quand de nouvelles annonces matchent une zone ou un interet actif.",
    skipWhen: ["Desabonnement marketing", "Aucune annonce pertinente"],
    unsubscribeAllowed: true,
    requiredPreferences: ["marketingEmailEnabled"],
    idempotencyScope: "userId + geo digest window",
  },
});