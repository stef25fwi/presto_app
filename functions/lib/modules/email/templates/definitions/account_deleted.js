"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.accountDeletedTemplate = void 0;
const shared_1 = require("./shared");
exports.accountDeletedTemplate = (0, shared_1.defineTemplate)({
    id: "account_deleted",
    templateCode: "tpl_transactional_account_deleted_v1",
    category: "security",
    type: "transactional",
    tone: "security",
    goal: "Notifier la suppression effective et laisser une voie de support/RGPD.",
    event: "user.account.deleted",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "feedbackUrl", type: "url", required: false, description: "Lien retour experience" },
        { key: "supportUrl", type: "url", required: false, description: "Lien support" },
    ],
    subject: "Votre compte e-livre resto a ete supprime",
    previewText: "Confirmation de suppression effective et informations utiles apres cloture.",
    secondaryCta: { label: "Contacter le support", urlVariable: "supportUrl", secondary: true },
    html: (0, shared_1.buildEmailHtml)({
        title: "Compte supprime",
        previewText: "Confirmation de suppression effective et informations utiles apres cloture.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre compte e-livre resto a bien ete supprime conformement a votre demande.",
            "Les acces associes ont ete fermes et les traitements restants seront limites a nos obligations legales et comptables.",
            "Si vous souhaitez nous faire un retour sur votre experience, vous pouvez utiliser le lien prevu a cet effet.",
        ],
        secondaryLabel: "Contacter le support",
        secondaryVariable: "supportUrl",
        tone: "security",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Compte supprime",
        previewText: "Confirmation de suppression effective et informations utiles apres cloture.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre compte e-livre resto a bien ete supprime.",
            "Les acces associes ont ete fermes.",
        ],
        secondaryLabel: "Contacter le support",
        secondaryVariable: "supportUrl",
    }),
    rules: {
        trigger: "user.account.deleted",
        sendWhen: "Quand la suppression de compte est devenue effective.",
        skipWhen: ["Adresse email deja purgee"],
        unsubscribeAllowed: false,
        requiredPreferences: ["transactionalEmailEnabled"],
        idempotencyScope: "userId + deleted_at",
    },
});
//# sourceMappingURL=account_deleted.js.map