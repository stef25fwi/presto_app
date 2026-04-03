"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.firstListingNotPublishedTemplate = void 0;
const shared_1 = require("./shared");
exports.firstListingNotPublishedTemplate = (0, shared_1.defineTemplate)({
    id: "first_listing_not_published",
    templateCode: "tpl_lifecycle_first_listing_not_published_v1",
    category: "growth",
    type: "lifecycle",
    tone: "onboarding",
    goal: "Relancer les brouillons d annonce jamais publies.",
    event: "listing.first_not_published.reminder",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "publishUrl", type: "url", required: true, description: "Lien pour finaliser la publication" },
        { key: "listingDraftTitle", type: "string", required: false, description: "Titre du brouillon" },
    ],
    subject: "Votre premiere annonce vous attend",
    previewText: "Finalisez votre brouillon et mettez votre annonce en ligne.",
    cta: { label: "Finaliser ma publication", urlVariable: "publishUrl" },
    html: (0, shared_1.buildEmailHtml)({
        title: "Votre premiere annonce est presque prete",
        previewText: "Finalisez votre brouillon et mettez votre annonce en ligne.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Vous avez deja commence une annonce {{listingDraftTitle}}, mais elle n a pas encore ete publiee.",
            "La mettre en ligne vous permettra de commencer a recevoir des contacts plus rapidement.",
        ],
        ctaLabel: "Finaliser ma publication",
        ctaVariable: "publishUrl",
        tone: "onboarding",
        type: "lifecycle",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Votre premiere annonce est presque prete",
        previewText: "Finalisez votre brouillon et mettez votre annonce en ligne.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Vous avez deja commence une annonce {{listingDraftTitle}}, mais elle n a pas encore ete publiee.",
        ],
        ctaLabel: "Finaliser ma publication",
        ctaVariable: "publishUrl",
    }),
    rules: {
        trigger: "listing.first_not_published.reminder",
        sendWhen: "Quand un premier brouillon reste non publie apres la fenetre d activation.",
        skipWhen: ["Annonce deja publiee", "Utilisateur inactif ferme"],
        unsubscribeAllowed: false,
        requiredPreferences: ["lifecycleEmailEnabled"],
        idempotencyScope: "userId + first listing reminder stage",
    },
});
//# sourceMappingURL=first_listing_not_published.js.map