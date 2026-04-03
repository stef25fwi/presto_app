"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listingUnderReviewTemplate = void 0;
const shared_1 = require("./shared");
exports.listingUnderReviewTemplate = (0, shared_1.defineTemplate)({
    id: "listing_under_review",
    templateCode: "tpl_transactional_listing_under_review_v2",
    category: "core_product",
    type: "transactional",
    tone: "onboarding",
    goal: "Confirmer la prise en charge d une annonce en moderation.",
    event: "listing.submitted",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "listingTitle", type: "string", required: true, description: "Titre de l annonce" },
        { key: "listingUrl", type: "url", required: false, description: "Lien de suivi annonce" },
    ],
    subject: "Votre annonce est en cours de moderation",
    previewText: "Nous verifions votre annonce avant publication pour garantir une place de marche fiable.",
    cta: { label: "Suivre mon annonce", urlVariable: "listingUrl" },
    html: (0, shared_1.buildEmailHtml)({
        title: "Annonce en cours de moderation",
        previewText: "Nous verifions votre annonce avant publication pour garantir une place de marche fiable.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Nous avons bien recu votre annonce : <strong>{{listingTitle}}</strong>.",
            "Notre equipe ou nos controles automatiques la verifient avant mise en ligne.",
            "Vous recevrez une confirmation des qu elle sera publiee ou si une correction est necessaire.",
        ],
        ctaLabel: "Suivre mon annonce",
        ctaVariable: "listingUrl",
        tone: "onboarding",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Annonce en cours de moderation",
        previewText: "Nous verifions votre annonce avant publication pour garantir une place de marche fiable.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Annonce recue : {{listingTitle}}.",
            "Elle est actuellement en cours de moderation.",
        ],
        ctaLabel: "Suivre mon annonce",
        ctaVariable: "listingUrl",
    }),
    rules: {
        trigger: "listing.submitted",
        sendWhen: "A chaque soumission valide d annonce.",
        skipWhen: ["Annonce deja en moderation et email deja emis"],
        unsubscribeAllowed: false,
        requiredPreferences: ["transactionalEmailEnabled"],
        idempotencyScope: "listingId + moderation submission",
    },
});
//# sourceMappingURL=listing_under_review.js.map