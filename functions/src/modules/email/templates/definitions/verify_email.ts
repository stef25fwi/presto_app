import { defineTemplate, buildEmailHtml, buildEmailText } from "./shared";

export const verifyEmailTemplate = defineTemplate({
  id: "verify_email",
  templateCode: "tpl_transactional_account_email_verification_v2",
  category: "security",
  type: "transactional",
  tone: "security",
  goal: "Verifier l adresse email du compte avant usage complet.",
  event: "user.email_verification.requested",
  variables: [
    { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
    { key: "verificationUrl", type: "url", required: true, description: "Lien de verification signe" },
  ],
  subject: "Confirmez votre adresse e-mail",
  previewText: "Validez votre adresse pour activer et securiser votre compte.",
  cta: { label: "Verifier mon e-mail", urlVariable: "verificationUrl" },
  html: buildEmailHtml({
    title: "Confirmez votre adresse e-mail",
    previewText: "Validez votre adresse pour activer et securiser votre compte.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Merci d avoir cree votre compte e-livre resto.",
      "Pour finaliser votre inscription, confirmez votre adresse e-mail en cliquant sur le bouton ci-dessous.",
      "Si vous n etes pas a l origine de cette demande, vous pouvez ignorer cet email.",
    ],
    ctaLabel: "Verifier mon e-mail",
    ctaVariable: "verificationUrl",
    tone: "security",
    type: "transactional",
  }),
  text: buildEmailText({
    title: "Confirmez votre adresse e-mail",
    previewText: "Validez votre adresse pour activer et securiser votre compte.",
    intro: "Bonjour {{firstName}},",
    body: [
      "Merci d avoir cree votre compte e-livre resto.",
      "Pour finaliser votre inscription, confirmez votre adresse e-mail.",
      "Si vous n etes pas a l origine de cette demande, ignorez cet email.",
    ],
    ctaLabel: "Verifier mon e-mail",
    ctaVariable: "verificationUrl",
  }),
  rules: {
    trigger: "user.email_verification.requested",
    sendWhen: "Quand un utilisateur demande ou necessite une verification email.",
    skipWhen: ["Adresse email absente", "Compte deja verifie"],
    unsubscribeAllowed: false,
    requiredPreferences: ["transactionalEmailEnabled"],
    idempotencyScope: "userId + fenetre de verification",
  },
});