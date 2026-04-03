"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loginOtpTemplate = void 0;
const shared_1 = require("./shared");
exports.loginOtpTemplate = (0, shared_1.defineTemplate)({
    id: "login_otp",
    templateCode: "tpl_transactional_account_login_otp_v1",
    category: "security",
    type: "transactional",
    tone: "security",
    goal: "Permettre une connexion OTP en email avec expiration courte.",
    event: "user.otp.requested",
    variables: [
        { key: "firstName", type: "string", required: true, description: "Prenom du destinataire" },
        { key: "otpCode", type: "string", required: true, description: "Code OTP" },
        { key: "expiresInMinutes", type: "number", required: true, description: "Expiration en minutes" },
        { key: "device", type: "string", required: false, description: "Appareil demandeur" },
        { key: "ip", type: "string", required: false, description: "Adresse IP demandeuse" },
        { key: "helpUrl", type: "url", required: false, description: "Lien support securite" },
    ],
    subject: "Votre code de connexion e-livre resto",
    previewText: "Utilisez ce code a usage unique pour vous connecter en toute securite.",
    secondaryCta: { label: "Besoin d aide", urlVariable: "helpUrl", secondary: true },
    html: (0, shared_1.buildEmailHtml)({
        title: "Votre code de connexion",
        previewText: "Utilisez ce code a usage unique pour vous connecter en toute securite.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Voici votre code de connexion a usage unique : <strong style=\"font-size:28px;letter-spacing:0.18em;color:#111827\">{{otpCode}}</strong>",
            "Ce code expire dans {{expiresInMinutes}} minutes.",
            "Demande detectee depuis : {{device}} {{ip}}",
            "Si vous n etes pas a l origine de cette tentative, ne partagez jamais ce code.",
        ],
        secondaryLabel: "Contacter le support",
        secondaryVariable: "helpUrl",
        tone: "security",
        type: "transactional",
    }),
    text: (0, shared_1.buildEmailText)({
        title: "Votre code de connexion",
        previewText: "Utilisez ce code a usage unique pour vous connecter en toute securite.",
        intro: "Bonjour {{firstName}},",
        body: [
            "Code OTP : {{otpCode}}",
            "Expiration : {{expiresInMinutes}} minutes.",
            "Appareil : {{device}}",
            "IP : {{ip}}",
            "Si vous n etes pas a l origine de cette demande, ignorez cet email.",
        ],
        secondaryLabel: "Contacter le support",
        secondaryVariable: "helpUrl",
    }),
    rules: {
        trigger: "user.otp.requested",
        sendWhen: "Quand une authentification OTP email est demandee.",
        skipWhen: ["OTP deja valide", "Compte verrouille"],
        unsubscribeAllowed: false,
        requiredPreferences: ["transactionalEmailEnabled"],
        idempotencyScope: "userId + otp session",
    },
});
//# sourceMappingURL=login_otp.js.map