"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.subscriptionExpiredTemplate = void 0;
const shared_1 = require("./shared");
exports.subscriptionExpiredTemplate = (0, shared_1.defineTemplate)({
    id: "subscription_expired",
    templateCode: "tpl_transactional_subscription_expired_v1",
    category: "billing",
    type: "transactional",
    tone: "security",
    goal: "Informer de l expiration d abonnement et proposer une reactivation rapide.",
    event: "billing.subscription.expired",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "planName", type: "string", required: true, description: "Nom du plan" },
        { key: "reactivateUrl", type: "url", required: true, description: "Lien de reactivation" },
    ],
    subject: "Votre abonnement a expire",
    previewText: "Reactiver votre plan pour retrouver l ensemble de vos fonctionnalites.",
    cta: { label: "Reactiver mon abonnement", urlVariable: "reactivateUrl" },
    html: (0, shared_1.buildEmailHtml)({
        title: "Abonnement expire",
        previewText: "Reactiver votre plan pour retrouver l ensemble de vos fonctionnalites.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre abonnement <strong>{{planName}}</strong> a expire.",
            "Certaines fonctionnalites peuvent etre limitees tant que le plan n est pas reactive.",
            "Vous pouvez reprendre votre activite en quelques clics.",
        ],
        ctaLabel: "Reactiver mon abonnement",
        ctaVariable: "reactivateUrl",
        tone: "security",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Abonnement expire",
        previewText: "Reactiver votre plan pour retrouver l ensemble de vos fonctionnalites.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Votre abonnement {{planName}} a expire.",
            "Certaines fonctionnalites peuvent etre limitees tant qu il n est pas reactive.",
        ],
        ctaLabel: "Reactiver mon abonnement",
        ctaVariable: "reactivateUrl",
    }),
    rules: {
        trigger: "billing.subscription.expired",
        sendWhen: "Quand un abonnement arrive a expiration effective.",
        skipWhen: ["Abonnement deja reactive"],
        unsubscribeAllowed: false,
        requiredPreferences: ["transactionalEmailEnabled"],
        idempotencyScope: "subscriptionId + expired_at",
    },
});
//# sourceMappingURL=subscription_expired.js.map