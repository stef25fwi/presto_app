"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.accountVerifiedTemplate = void 0;
const shared_1 = require("./shared");
exports.accountVerifiedTemplate = (0, shared_1.defineTemplate)({
    id: "account_verified",
    templateCode: "tpl_lifecycle_account_verified_v1",
    category: "core_product",
    type: "lifecycle",
    tone: "onboarding",
    goal: "Confirmer la verification du compte et pousser la prochaine action utile.",
    event: "profile.verified",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "dashboardUrl", type: "url", required: true, description: "Lien espace utilisateur" },
    ],
    subject: "Votre compte est verifie",
    previewText: "Votre adresse email est confirmee. Vous pouvez utiliser pleinement e-livre resto.",
    cta: { label: "Acceder a mon espace", urlVariable: "dashboardUrl" },
    html: (0, shared_1.buildEmailHtml)({
        title: "Compte verifie",
        previewText: "Votre adresse email est confirmee. Vous pouvez utiliser pleinement e-livre resto.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre compte a bien ete verifie.",
            "Vous pouvez maintenant publier, echanger par messagerie et suivre vos activites avec un niveau de confiance renforce.",
        ],
        ctaLabel: "Acceder a mon espace",
        ctaVariable: "dashboardUrl",
        tone: "onboarding",
        type: "lifecycle",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Compte verifie",
        previewText: "Votre adresse email est confirmee. Vous pouvez utiliser pleinement e-livre resto.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre compte a bien ete verifie.",
            "Vous pouvez maintenant utiliser pleinement e-livre resto.",
        ],
        ctaLabel: "Acceder a mon espace",
        ctaVariable: "dashboardUrl",
    }),
    rules: {
        trigger: "profile.verified",
        sendWhen: "Apres verification email ou validation de compte.",
        skipWhen: ["Evenement deja envoye pour ce compte"],
        unsubscribeAllowed: false,
        requiredPreferences: ["lifecycleEmailEnabled"],
        idempotencyScope: "userId + verification milestone",
    },
});
//# sourceMappingURL=account_verified.js.map