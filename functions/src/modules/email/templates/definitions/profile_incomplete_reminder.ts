import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const profileIncompleteReminderTemplate = defineTemplate({
  id: "profile_incomplete_reminder",
  templateCode: "tpl_lifecycle_profile_incomplete_reminder_v1",
  category: "core_product",
  type: "lifecycle",
  tone: "onboarding",
  goal: "Relancer la completion du profil pour ameliorer activation et confiance.",
  event: "profile.incomplete.reminder",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "completionUrl", type: "url", required: true, description: "Lien profil" },
    { key: "missingFieldsSummary", type: "string", required: true, description: "Resume des champs manquants" },
  ],
  subject: "Finalisez votre profil pour gagner en confiance",
  previewText: "Quelques informations manquent encore pour activer pleinement votre compte.",
  cta: { label: "Completer mon profil", urlVariable: "completionUrl" },
  html: buildEmailHtml({
    title: "Votre profil est presque pret",
    previewText: "Quelques informations manquent encore pour activer pleinement votre compte.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Votre compte est cree, mais certains elements de profil sont encore incomplets.",
      "A completer en priorite : {{missingFieldsSummary}}.",
      "Un profil complet inspire davantage confiance et accelere les prises de contact.",
    ],
    ctaLabel: "Completer mon profil",
    ctaVariable: "completionUrl",
    tone: "onboarding",
    type: "lifecycle",
  }),
  text: buildEmailText({
    title: "Votre profil est presque pret",
    previewText: "Quelques informations manquent encore pour activer pleinement votre compte.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Des elements de profil sont encore incomplets.",
      "A completer en priorite : {{missingFieldsSummary}}.",
    ],
    ctaLabel: "Completer mon profil",
    ctaVariable: "completionUrl",
  }),
  rules: {
    trigger: "profile.incomplete.reminder",
    sendWhen: "Quand un profil reste incomplet apres activation initiale.",
    skipWhen: ["Profil deja complet", "Compte supprime"],
    unsubscribeAllowed: false,
    requiredPreferences: ["lifecycleEmailEnabled"],
    idempotencyScope: "userId + reminder stage",
  },
});