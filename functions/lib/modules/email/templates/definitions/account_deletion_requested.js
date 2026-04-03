"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.accountDeletionRequestedTemplate = void 0;
const shared_1 = require("./shared");
exports.accountDeletionRequestedTemplate = (0, shared_1.defineTemplate)({
    id: "account_deletion_requested",
    templateCode: "tpl_transactional_account_deletion_requested_v1",
    category: "security",
    type: "transactional",
    tone: "security",
    goal: "Confirmer une demande de suppression et permettre son annulation tant que possible.",
    event: "user.account.deletion.requested",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "deletionDate", type: "date", required: true, description: "Date effective de suppression" },
        { key: "cancelDeletionUrl", type: "url", required: true, description: "Lien d annulation" },
        { key: "supportUrl", type: "url", required: false, description: "Lien support" },
    ],
    subject: "Votre demande de suppression de compte a bien ete prise en compte",
    previewText: "Votre compte sera supprime a la date indiquee, sauf annulation de votre part.",
    cta: { label: "Annuler la suppression", urlVariable: "cancelDeletionUrl" },
    secondaryCta: { label: "Contacter le support", urlVariable: "supportUrl", secondary: true },
    html: (0, shared_1.buildEmailHtml)({
        title: "Suppression de compte programmee",
        previewText: "Votre compte sera supprime a la date indiquee, sauf annulation de votre part.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Nous confirmons la demande de suppression de votre compte e-livre resto.",
            "La suppression definitive interviendra le {{deletionDate}}.",
            "Si vous changez d avis avant cette date, vous pouvez annuler la procedure depuis le bouton ci-dessous.",
        ],
        ctaLabel: "Annuler la suppression",
        ctaVariable: "cancelDeletionUrl",
        secondaryLabel: "Contacter le support",
        secondaryVariable: "supportUrl",
        tone: "security",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Suppression de compte programmee",
        previewText: "Votre compte sera supprime a la date indiquee, sauf annulation de votre part.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Nous confirmons votre demande de suppression de compte.",
            "Suppression definitive prevue le {{deletionDate}}.",
            "Vous pouvez encore annuler cette procedure avant l echeance.",
        ],
        ctaLabel: "Annuler la suppression",
        ctaVariable: "cancelDeletionUrl",
        secondaryLabel: "Contacter le support",
        secondaryVariable: "supportUrl",
    }),
    rules: {
        trigger: "user.account.deletion.requested",
        sendWhen: "Quand la suppression de compte est demandee et planifiee.",
        skipWhen: ["Compte deja supprime", "Annulation deja effectuee"],
        unsubscribeAllowed: false,
        requiredPreferences: ["transactionalEmailEnabled"],
        idempotencyScope: "userId + deletion request id",
    },
});
//# sourceMappingURL=account_deletion_requested.js.map