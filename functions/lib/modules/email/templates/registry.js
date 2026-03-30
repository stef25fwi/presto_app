"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.templateRegistry = void 0;
exports.getTemplateMeta = getTemplateMeta;
exports.listMissingRequiredVariables = listMissingRequiredVariables;
exports.getDefaultTemplateContent = getDefaultTemplateContent;
exports.templateRegistry = [
    // ── Compte & Auth ─────────────────────────────────────────────────────────
    {
        template_code: "tpl_transactional_account_welcome_v1",
        channel: "transactionnel",
        category: "account_auth",
        required_variables: ["firstName", "dashboardUrl"],
        default_subject_fr: "Bienvenue sur PRESTO 🎉",
        default_preheader_fr: "Votre compte est prêt, découvrez PRESTO",
    },
    {
        template_code: "tpl_transactional_account_email_verification_v1",
        channel: "transactionnel",
        category: "account_auth",
        required_variables: ["firstName", "verificationUrl"],
        default_subject_fr: "Confirmez votre adresse e-mail",
        default_preheader_fr: "Cliquez pour vérifier votre e-mail",
    },
    {
        template_code: "tpl_transactional_account_password_forgotten_v1",
        channel: "transactionnel",
        category: "account_auth",
        required_variables: ["firstName", "resetUrl"],
        default_subject_fr: "Réinitialiser votre mot de passe",
        default_preheader_fr: "Lien valable 1 heure",
    },
    {
        template_code: "tpl_transactional_account_password_changed_v1",
        channel: "transactionnel",
        category: "account_auth",
        required_variables: ["firstName"],
        default_subject_fr: "Votre mot de passe a été modifié",
        default_preheader_fr: "Si ce n'est pas vous, contactez le support",
    },
    {
        template_code: "tpl_transactional_account_suspicious_login_v1",
        channel: "transactionnel",
        category: "account_auth",
        required_variables: ["firstName", "ip", "device", "secureUrl"],
        default_subject_fr: "Connexion suspecte détectée",
        default_preheader_fr: "Sécurisez votre compte maintenant",
    },
    // ── Annonces ──────────────────────────────────────────────────────────────
    {
        template_code: "tpl_transactional_listing_submitted_v1",
        channel: "transactionnel",
        category: "listings",
        required_variables: ["firstName", "listingTitle"],
        default_subject_fr: "Votre annonce est en cours de modération",
        default_preheader_fr: "Nous la vérifions sous 24h",
    },
    {
        template_code: "tpl_transactional_listing_published_v1",
        channel: "transactionnel",
        category: "listings",
        required_variables: ["listingTitle", "listingUrl"],
        default_subject_fr: "Votre annonce est en ligne !",
        default_preheader_fr: "Elle est désormais visible par les prestataires",
    },
    {
        template_code: "tpl_transactional_listing_rejected_v1",
        channel: "transactionnel",
        category: "listings",
        required_variables: ["firstName", "listingTitle", "rejectionReason", "editUrl"],
        default_subject_fr: "Votre annonce n'a pas été publiée",
        default_preheader_fr: "Voici pourquoi et comment la corriger",
    },
    {
        template_code: "tpl_transactional_listing_expired_v1",
        channel: "transactionnel",
        category: "listings",
        required_variables: ["listingTitle", "renewUrl"],
        default_subject_fr: "Votre annonce a expiré",
        default_preheader_fr: "Réactivez-la pour continuer à recevoir des contacts",
    },
    {
        template_code: "tpl_product_listing_expiring_soon_v1",
        channel: "produit",
        category: "listings",
        required_variables: ["listingTitle", "renewUrl"],
        default_subject_fr: "Votre annonce expire bientôt",
        default_preheader_fr: "Renouvelez-la en un clic",
    },
    // ── Messagerie ────────────────────────────────────────────────────────────
    {
        template_code: "tpl_product_messaging_new_message_v1",
        channel: "produit",
        category: "messaging",
        required_variables: ["senderName", "conversationUrl"],
        default_subject_fr: "Nouveau message reçu sur PRESTO",
        default_preheader_fr: "Ouvrez la conversation maintenant",
    },
    {
        template_code: "tpl_product_messaging_pending_reminder_v1",
        channel: "produit",
        category: "messaging",
        required_variables: ["conversationUrl"],
        default_subject_fr: "Vous avez un message sans réponse",
        default_preheader_fr: "Ne laissez pas cette opportunité passer",
    },
    // ── Leads ─────────────────────────────────────────────────────────────────
    {
        template_code: "tpl_product_lead_received_v1",
        channel: "produit",
        category: "listings",
        required_variables: ["listingTitle", "senderName", "conversationUrl"],
        default_subject_fr: "Une candidature pour votre annonce",
        default_preheader_fr: "Un prestataire souhaite vous contacter",
    },
    // ── Recherches sauvegardées ───────────────────────────────────────────────
    {
        template_code: "tpl_product_saved_search_match_found_v1",
        channel: "produit",
        category: "saved_search",
        required_variables: ["searchName", "matchCount", "resultsUrl"],
        default_subject_fr: "De nouvelles annonces correspondent à votre alerte",
        default_preheader_fr: "{{matchCount}} résultat(s) trouvé(s)",
    },
    // ── Support ───────────────────────────────────────────────────────────────
    {
        template_code: "tpl_transactional_support_ticket_created_v1",
        channel: "transactionnel",
        category: "support",
        required_variables: ["firstName", "ticketNumber", "ticketSubject"],
        default_subject_fr: "Votre demande d'assistance #{{ticketNumber}}",
        default_preheader_fr: "Nous avons bien reçu votre message",
    },
    {
        template_code: "tpl_transactional_support_reply_v1",
        channel: "transactionnel",
        category: "support",
        required_variables: ["firstName", "ticketNumber", "replyUrl"],
        default_subject_fr: "Réponse à votre demande #{{ticketNumber}}",
        default_preheader_fr: "L'équipe PRESTO vous a répondu",
    },
    // ── Modération ────────────────────────────────────────────────────────────
    {
        template_code: "tpl_transactional_moderation_report_received_v1",
        channel: "transactionnel",
        category: "moderation",
        required_variables: ["firstName"],
        default_subject_fr: "Votre signalement a été pris en compte",
        default_preheader_fr: "Merci de contribuer à la sécurité de PRESTO",
    },
    {
        template_code: "tpl_transactional_moderation_report_resolved_v1",
        channel: "transactionnel",
        category: "moderation",
        required_variables: ["firstName", "reportUrl", "resolutionSummary"],
        default_subject_fr: "Votre signalement a été traité",
        default_preheader_fr: "Consultez la décision de notre équipe",
    },
    // ── Légal ─────────────────────────────────────────────────────────────────
    {
        template_code: "tpl_transactional_legal_terms_updated_v1",
        channel: "transactionnel",
        category: "legal",
        required_variables: ["termsUrl", "effectiveDate"],
        default_subject_fr: "Mise à jour de nos conditions générales",
        default_preheader_fr: "Applicables à partir du {{effectiveDate}}",
    },
    {
        template_code: "tpl_transactional_legal_privacy_updated_v1",
        channel: "transactionnel",
        category: "legal",
        required_variables: ["privacyUrl", "effectiveDate"],
        default_subject_fr: "Mise à jour de notre politique de confidentialité",
        default_preheader_fr: "Consultez les changements applicables le {{effectiveDate}}",
    },
    // ── Marketing / Onboarding ─────────────────────────────────────────────────
    {
        template_code: "tpl_marketing_onboarding_d1_v1",
        channel: "marketing",
        category: "onboarding",
        required_variables: ["firstName", "dashboardUrl"],
        default_subject_fr: "Comment bien démarrer sur PRESTO",
        default_preheader_fr: "3 astuces pour trouver rapidement un prestataire",
    },
    {
        template_code: "tpl_marketing_onboarding_d3_v1",
        channel: "marketing",
        category: "onboarding",
        required_variables: ["firstName", "createListingUrl"],
        default_subject_fr: "Publiez votre première annonce gratuitement",
        default_preheader_fr: "Des prestataires locaux attendent votre demande",
    },
    {
        template_code: "tpl_marketing_onboarding_d7_v1",
        channel: "marketing",
        category: "onboarding",
        required_variables: ["firstName", "exploreUrl"],
        default_subject_fr: "Découvrez les prestataires près de chez vous",
        default_preheader_fr: "Des milliers de pros disponibles en Guadeloupe et Martinique",
    },
    {
        template_code: "tpl_marketing_newsletter_v1",
        channel: "marketing",
        category: "marketing",
        required_variables: ["newsletterTitle", "newsletterUrl"],
        default_subject_fr: "Newsletter PRESTO",
        default_preheader_fr: "Nouveautés et opportunités locales",
    },
    // ── Abonnement & Facturation ──────────────────────────────────────────────
    {
        template_code: "tpl_transactional_subscription_renewal_upcoming_v1",
        channel: "transactionnel",
        category: "billing",
        required_variables: ["firstName", "renewalDate", "planName", "manageUrl"],
        default_subject_fr: "Votre abonnement PRESTO se renouvelle bientôt",
        default_preheader_fr: "Renouvellement le {{renewalDate}}",
    },
    {
        template_code: "tpl_transactional_billing_payment_succeeded_v1",
        channel: "transactionnel",
        category: "billing",
        required_variables: ["firstName", "amount", "invoiceUrl"],
        default_subject_fr: "Paiement confirmé",
        default_preheader_fr: "Votre facture PRESTO a bien été réglée",
    },
    {
        template_code: "tpl_transactional_billing_payment_failed_v1",
        channel: "transactionnel",
        category: "billing",
        required_variables: ["firstName", "amount", "retryUrl"],
        default_subject_fr: "Échec du paiement de votre abonnement",
        default_preheader_fr: "Mettez à jour vos informations de paiement",
    },
];
function getTemplateMeta(templateCode) {
    return exports.templateRegistry.find((item) => item.template_code === templateCode) || null;
}
function listMissingRequiredVariables(templateCode, payload) {
    const meta = getTemplateMeta(templateCode);
    if (!meta)
        return [];
    return meta.required_variables.filter((key) => {
        const value = payload[key];
        if (value === undefined || value === null)
            return true;
        if (typeof value === "string")
            return value.trim().length === 0;
        return false;
    });
}
function wrapDefaultHtml(subject, preheader, body) {
    return (`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>${subject}</title></head>` +
        `<body style="font-family:Arial,sans-serif;max-width:640px;margin:auto;padding:24px;color:#111827">` +
        `<div style="padding:24px;border:1px solid #E5E7EB;border-radius:16px">` +
        `<div style="margin-bottom:8px">` +
        `<img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0;outline:none;text-decoration:none">` +
        `</div>` +
        `<div style="font-size:14px;color:#6B7280;margin-bottom:20px">${preheader}</div>` +
        `${body}` +
        `<hr style="margin:24px 0;border:none;border-top:1px solid #E5E7EB">` +
        `<p style="font-size:12px;color:#6B7280">Vous recevez cet e-mail car vous utilisez PRESTO.</p>` +
        `</div></body></html>`);
}
function wrapDefaultText(subject, preheader, body) {
    return `PRESTO\n\n${subject}\n\n${preheader}\n\n${body}\n`;
}
function getDefaultTemplateContent(templateCode, locale) {
    const meta = getTemplateMeta(templateCode);
    const subject = meta?.default_subject_fr ?? templateCode;
    const preheader = meta?.default_preheader_fr ?? "";
    const frBodies = {
        tpl_transactional_account_welcome_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Bienvenue sur PRESTO.</p><p><a href="{{dashboardUrl}}">Accéder à mon espace</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nBienvenue sur PRESTO.\n{{dashboardUrl}}`),
        },
        tpl_transactional_account_email_verification_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Confirmez votre adresse e-mail.</p><p><a href="{{verificationUrl}}">Vérifier mon e-mail</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVérifiez votre e-mail:\n{{verificationUrl}}`),
        },
        tpl_transactional_account_password_forgotten_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Réinitialisez votre mot de passe.</p><p><a href="{{resetUrl}}">Réinitialiser</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nRéinitialisation:\n{{resetUrl}}`),
        },
        tpl_transactional_account_password_changed_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre mot de passe a été modifié.</p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVotre mot de passe a été modifié.`),
        },
        tpl_transactional_account_suspicious_login_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Connexion détectée depuis {{device}} (IP {{ip}}).</p><p><a href="{{secureUrl}}">Sécuriser mon compte</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nConnexion depuis {{device}} (IP {{ip}}).\n{{secureUrl}}`),
        },
        tpl_transactional_listing_submitted_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre annonce {{listingTitle}} est en cours de modération.</p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVotre annonce {{listingTitle}} est en cours de modération.`),
        },
        tpl_transactional_listing_published_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Votre annonce {{listingTitle}} est en ligne.</p><p><a href="{{listingUrl}}">Voir mon annonce</a></p>`),
            text: wrapDefaultText(subject, preheader, `Votre annonce {{listingTitle}} est en ligne.\n{{listingUrl}}`),
        },
        tpl_transactional_listing_rejected_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre annonce {{listingTitle}} n'a pas été publiée.</p><p>Raison: {{rejectionReason}}</p><p><a href="{{editUrl}}">Corriger l'annonce</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nAnnonce refusée: {{listingTitle}}\nRaison: {{rejectionReason}}\n{{editUrl}}`),
        },
        tpl_transactional_listing_expired_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Votre annonce {{listingTitle}} a expiré.</p><p><a href="{{renewUrl}}">La réactiver</a></p>`),
            text: wrapDefaultText(subject, preheader, `Votre annonce {{listingTitle}} a expiré.\n{{renewUrl}}`),
        },
        tpl_product_listing_expiring_soon_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Votre annonce {{listingTitle}} expire bientôt.</p><p><a href="{{renewUrl}}">Renouveler</a></p>`),
            text: wrapDefaultText(subject, preheader, `Votre annonce {{listingTitle}} expire bientôt.\n{{renewUrl}}`),
        },
        tpl_product_messaging_new_message_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>{{senderName}} vous a envoyé un message.</p><p><a href="{{conversationUrl}}">Ouvrir la conversation</a></p>`),
            text: wrapDefaultText(subject, preheader, `Nouveau message de {{senderName}}.\n{{conversationUrl}}`),
        },
        tpl_product_messaging_pending_reminder_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Vous avez une conversation en attente.</p><p><a href="{{conversationUrl}}">Répondre maintenant</a></p>`),
            text: wrapDefaultText(subject, preheader, `Vous avez une conversation en attente.\n{{conversationUrl}}`),
        },
        tpl_product_lead_received_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>{{senderName}} est intéressé par {{listingTitle}}.</p><p><a href="{{conversationUrl}}">Voir la candidature</a></p>`),
            text: wrapDefaultText(subject, preheader, `{{senderName}} est intéressé par {{listingTitle}}.\n{{conversationUrl}}`),
        },
        tpl_product_saved_search_match_found_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>{{searchName}}: {{matchCount}} nouvelle(s) annonce(s).</p><p><a href="{{resultsUrl}}">Voir les résultats</a></p>`),
            text: wrapDefaultText(subject, preheader, `{{searchName}}: {{matchCount}} nouvelle(s) annonce(s).\n{{resultsUrl}}`),
        },
        tpl_transactional_support_ticket_created_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre demande #{{ticketNumber}} a bien été reçue.</p><p>Sujet: {{ticketSubject}}</p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVotre demande #{{ticketNumber}} a été reçue.\nSujet: {{ticketSubject}}`),
        },
        tpl_transactional_support_reply_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Nous avons répondu à votre demande #{{ticketNumber}}.</p><p><a href="{{replyUrl}}">Lire la réponse</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nRéponse à votre demande #{{ticketNumber}}.\n{{replyUrl}}`),
        },
        tpl_transactional_moderation_report_received_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre signalement a été enregistré.</p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVotre signalement a été enregistré.`),
        },
        tpl_transactional_moderation_report_resolved_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre signalement a été traité.</p><p>{{resolutionSummary}}</p><p><a href="{{reportUrl}}">Consulter le suivi</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVotre signalement a été traité.\n{{resolutionSummary}}\n{{reportUrl}}`),
        },
        tpl_transactional_legal_terms_updated_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Nos conditions changent à partir du {{effectiveDate}}.</p><p><a href="{{termsUrl}}">Consulter les conditions</a></p>`),
            text: wrapDefaultText(subject, preheader, `Conditions applicables à partir du {{effectiveDate}}.\n{{termsUrl}}`),
        },
        tpl_transactional_legal_privacy_updated_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Notre politique de confidentialité évolue à partir du {{effectiveDate}}.</p><p><a href="{{privacyUrl}}">Consulter la politique</a></p>`),
            text: wrapDefaultText(subject, preheader, `Politique de confidentialité applicable à partir du {{effectiveDate}}.\n{{privacyUrl}}`),
        },
        tpl_marketing_onboarding_d1_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Découvrez vos premiers pas sur PRESTO.</p><p><a href="{{dashboardUrl}}">Commencer</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nPremiers pas sur PRESTO:\n{{dashboardUrl}}`),
        },
        tpl_marketing_onboarding_d3_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Publiez votre première annonce.</p><p><a href="{{createListingUrl}}">Créer une annonce</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nCréer une annonce:\n{{createListingUrl}}`),
        },
        tpl_marketing_onboarding_d7_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Explorez les prestataires près de chez vous.</p><p><a href="{{exploreUrl}}">Explorer</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nExplorer PRESTO:\n{{exploreUrl}}`),
        },
        tpl_marketing_newsletter_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>{{newsletterTitle}}</p><p><a href="{{newsletterUrl}}">Lire la newsletter</a></p>`),
            text: wrapDefaultText(subject, preheader, `{{newsletterTitle}}\n{{newsletterUrl}}`),
        },
        tpl_transactional_subscription_renewal_upcoming_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre abonnement {{planName}} se renouvelle le {{renewalDate}}.</p><p><a href="{{manageUrl}}">Gérer l'abonnement</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nRenouvellement de {{planName}} le {{renewalDate}}.\n{{manageUrl}}`),
        },
        tpl_transactional_billing_payment_succeeded_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Votre paiement de {{amount}} a bien été reçu.</p><p><a href="{{invoiceUrl}}">Consulter la facture</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nVotre paiement de {{amount}} a bien été reçu.\n{{invoiceUrl}}`),
        },
        tpl_transactional_billing_payment_failed_v1: {
            html: wrapDefaultHtml(subject, preheader, `<p>Bonjour {{firstName}},</p><p>Le paiement de {{amount}} a échoué.</p><p><a href="{{retryUrl}}">Mettre à jour le paiement</a></p>`),
            text: wrapDefaultText(subject, preheader, `Bonjour {{firstName}},\n\nLe paiement de {{amount}} a échoué.\n{{retryUrl}}`),
        },
    };
    return frBodies[templateCode];
}
//# sourceMappingURL=registry.js.map