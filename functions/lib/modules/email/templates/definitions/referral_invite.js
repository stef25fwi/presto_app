"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.referralInviteTemplate = void 0;
const shared_1 = require("./shared");
exports.referralInviteTemplate = (0, shared_1.defineTemplate)({
    id: "referral_invite",
    templateCode: "tpl_marketing_referral_invite_v1",
    category: "growth",
    type: "marketing",
    tone: "onboarding",
    goal: "Permettre une invitation de parrainage traquee et simple a partager.",
    event: "growth.referral_invite",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "inviterName", type: "string", required: true, description: "Nom du parrain" },
        { key: "referralUrl", type: "url", required: true, description: "Lien de parrainage" },
        { key: "rewardDescription", type: "string", required: true, description: "Description de la recompense" },
    ],
    subject: "{{inviterName}} vous invite sur e-livre resto",
    previewText: "Rejoignez la plateforme avec une invitation personnelle et decouvrez l avantage propose.",
    cta: { label: "Accepter l invitation", urlVariable: "referralUrl" },
    html: (0, shared_1.buildEmailHtml)({
        title: "Invitation personnelle",
        previewText: "Rejoignez la plateforme avec une invitation personnelle et decouvrez l avantage propose.",
        intro: "Bonjour {{firstName}},",
        body: [
            "{{inviterName}} vous invite a rejoindre e-livre resto.",
            "Avantage annonce : {{rewardDescription}}.",
            "Le lien ci-dessous vous permet de rejoindre la plateforme avec le bon suivi de parrainage.",
        ],
        ctaLabel: "Accepter l invitation",
        ctaVariable: "referralUrl",
        tone: "onboarding",
        type: "marketing",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Invitation personnelle",
        previewText: "Rejoignez la plateforme avec une invitation personnelle et decouvrez l avantage propose.",
        intro: "Bonjour {{firstName}},",
        body: [
            "{{inviterName}} vous invite a rejoindre e-livre resto.",
            "Avantage annonce : {{rewardDescription}}.",
        ],
        ctaLabel: "Accepter l invitation",
        ctaVariable: "referralUrl",
    }),
    rules: {
        trigger: "growth.referral_invite",
        sendWhen: "Quand une invitation de parrainage est emise pour un contact cible.",
        skipWhen: ["Desabonnement marketing", "Lien de parrainage expire"],
        unsubscribeAllowed: true,
        requiredPreferences: ["marketingEmailEnabled"],
        idempotencyScope: "referralId + recipientEmail",
    },
});
//# sourceMappingURL=referral_invite.js.map