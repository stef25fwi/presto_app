"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.templateRegistry = void 0;
exports.getTemplateMeta = getTemplateMeta;
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
    // ── Légal ─────────────────────────────────────────────────────────────────
    {
        template_code: "tpl_transactional_legal_terms_updated_v1",
        channel: "transactionnel",
        category: "legal",
        required_variables: ["termsUrl", "effectiveDate"],
        default_subject_fr: "Mise à jour de nos conditions générales",
        default_preheader_fr: "Applicables à partir du {{effectiveDate}}",
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
//# sourceMappingURL=registry.js.map