"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.messageReceivedTemplate = void 0;
const shared_1 = require("./shared");
exports.messageReceivedTemplate = (0, shared_1.defineTemplate)({
    id: "message_received",
    templateCode: "tpl_transactional_message_received_v2",
    category: "messaging",
    type: "transactional",
    tone: "trust",
    goal: "Notifier un nouveau message sans rompre la confidentialite du thread.",
    event: "conversation.message_received",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "senderName", type: "string", required: true, description: "Nom de l expediteur" },
        { key: "conversationUrl", type: "url", required: true, description: "Lien vers la conversation" },
        { key: "messagePreview", type: "string", required: false, description: "Extrait tronque du message" },
    ],
    subject: "Nouveau message de {{senderName}}",
    previewText: "Consultez rapidement votre conversation depuis votre espace e-livre resto.",
    cta: { label: "Ouvrir la conversation", urlVariable: "conversationUrl" },
    html: (0, shared_1.buildEmailHtml)({
        title: "Vous avez recu un nouveau message",
        previewText: "Consultez rapidement votre conversation depuis votre espace e-livre resto.",
        intro: "Bonjour {{firstName}},",
        body: [
            "<strong>{{senderName}}</strong> vous a envoye un nouveau message.",
            "Apercu : {{messagePreview}}",
            "Pour proteger vos echanges, repondez directement depuis la conversation securisee dans l application.",
        ],
        ctaLabel: "Ouvrir la conversation",
        ctaVariable: "conversationUrl",
        tone: "trust",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Vous avez recu un nouveau message",
        previewText: "Consultez rapidement votre conversation depuis votre espace e-livre resto.",
        intro: "Bonjour {{firstName}},",
        body: [
            "{{senderName}} vous a envoye un nouveau message.",
            "Apercu : {{messagePreview}}",
        ],
        ctaLabel: "Ouvrir la conversation",
        ctaVariable: "conversationUrl",
    }),
    rules: {
        trigger: "conversation.message_received",
        sendWhen: "Quand un nouveau message est recu hors session active ou selon regles de notification.",
        skipWhen: ["Conversation mutee", "Destinataire deja actif dans le thread"],
        unsubscribeAllowed: false,
        requiredPreferences: ["messageEmailEnabled"],
        idempotencyScope: "conversationId + messageId + recipientId",
    },
});
//# sourceMappingURL=message_received.js.map