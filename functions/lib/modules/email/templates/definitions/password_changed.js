"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.passwordChangedTemplate = void 0;
const shared_1 = require("./shared");
exports.passwordChangedTemplate = (0, shared_1.defineTemplate)({
    id: "password_changed",
    templateCode: "tpl_transactional_account_password_changed_v2",
    category: "security",
    type: "transactional",
    tone: "security",
    goal: "Informer d un changement de mot de passe et ouvrir une voie de recours.",
    event: "user.password_changed",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "supportUrl", type: "url", required: false, description: "Lien support securite" },
    ],
    subject: "Votre mot de passe a ete modifie",
    previewText: "Si vous n etes pas a l origine de cette action, securisez votre compte sans attendre.",
    secondaryCta: { label: "Contacter le support", urlVariable: "supportUrl", secondary: true },
    html: (0, shared_1.buildEmailHtml)({
        title: "Mot de passe modifie",
        previewText: "Si vous n etes pas a l origine de cette action, securisez votre compte sans attendre.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Le mot de passe de votre compte e-livre resto vient d etre modifie.",
            "Si cette action vient bien de vous, aucune autre etape n est necessaire.",
            "Si ce n etait pas vous, contactez immediatement le support et reinitialisez votre acces.",
        ],
        secondaryLabel: "Contacter le support",
        secondaryVariable: "supportUrl",
        tone: "security",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Mot de passe modifie",
        previewText: "Si vous n etes pas a l origine de cette action, securisez votre compte sans attendre.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Le mot de passe de votre compte e-livre resto vient d etre modifie.",
            "Si ce n etait pas vous, contactez immediatement le support.",
        ],
        secondaryLabel: "Contacter le support",
        secondaryVariable: "supportUrl",
    }),
    rules: {
        trigger: "user.password_changed",
        sendWhen: "Apres confirmation d un changement de mot de passe.",
        skipWhen: ["Aucun email associe au compte"],
        unsubscribeAllowed: false,
        requiredPreferences: ["transactionalEmailEnabled"],
        idempotencyScope: "userId + hour bucket",
    },
});
//# sourceMappingURL=password_changed.js.map