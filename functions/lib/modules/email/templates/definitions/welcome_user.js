"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.welcomeUserTemplate = void 0;
const shared_1 = require("./shared");
exports.welcomeUserTemplate = (0, shared_1.defineTemplate)({
    id: "welcome_user",
    templateCode: "tpl_transactional_account_welcome_v2",
    category: "core_product",
    type: "lifecycle",
    tone: "onboarding",
    goal: "Accueillir le nouvel utilisateur et lancer son activation produit.",
    event: "user.created",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "dashboardUrl", type: "url", required: true, description: "Lien tableau de bord" },
        { key: "publishUrl", type: "url", required: false, description: "Lien publication annonce" },
    ],
    subject: "Bienvenue sur e-livre resto",
    previewText: "Votre compte est pret. Publiez une annonce ou explorez les premiers services.",
    cta: { label: "Acceder a mon espace", urlVariable: "dashboardUrl" },
    secondaryCta: { label: "Publier une annonce", urlVariable: "publishUrl", secondary: true },
    html: (0, shared_1.buildEmailHtml)({
        title: "Bienvenue sur e-livre resto",
        previewText: "Votre compte est pret. Publiez une annonce ou explorez les premiers services.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre compte est maintenant pret a etre utilise.",
            "Vous pouvez publier une annonce, recevoir des messages et suivre vos demandes en un seul endroit.",
            "Nous avons concu l experience pour aller vite, tout en restant claire et rassurante pour vos clients et prestataires.",
        ],
        ctaLabel: "Acceder a mon espace",
        ctaVariable: "dashboardUrl",
        secondaryLabel: "Publier une annonce",
        secondaryVariable: "publishUrl",
        tone: "onboarding",
        type: "lifecycle",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Bienvenue sur e-livre resto",
        previewText: "Votre compte est pret. Publiez une annonce ou explorez les premiers services.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre compte est maintenant pret a etre utilise.",
            "Publiez une annonce, recevez des messages et suivez vos demandes facilement.",
        ],
        ctaLabel: "Acceder a mon espace",
        ctaVariable: "dashboardUrl",
        secondaryLabel: "Publier une annonce",
        secondaryVariable: "publishUrl",
    }),
    rules: {
        trigger: "user.created",
        sendWhen: "A la creation du compte utilisateur.",
        skipWhen: ["Utilisateur sans email"],
        unsubscribeAllowed: false,
        requiredPreferences: ["lifecycleEmailEnabled"],
        idempotencyScope: "userId",
    },
});
//# sourceMappingURL=welcome_user.js.map