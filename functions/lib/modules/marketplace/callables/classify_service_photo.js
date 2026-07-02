"use strict";
/**
 * classifyServicePhoto — Classification vision métier → clé enum fermé.
 *
 * Flux optimisé :
 *   Photo → GPT-4o-mini (classification enum ~400-600 ms)
 *           ↓
 *   { metier, confidence }   ← retourné au client
 *           ↓
 *   Lookup local kTradeLookup (~0 ms côté Flutter)
 *           ↓
 *   { categorie, sousCat, tags }  ← pré-remplissage instantané
 *
 * Pendant ce temps, generateOfferDraft tourne en parallèle pour titre + description.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifyServicePhoto = void 0;
const openai_1 = __importDefault(require("openai"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const logger_1 = require("../../../core/logger");
// ── Enum fermé (miroir de kTradeLookup dans trade_category_lookup.dart) ──────
const VALID_TRADE_KEYS = new Set([
    // Restauration
    "serveur", "barman", "plongeur", "commis_cuisine", "cuisinier",
    "snack", "food_truck", "traiteur", "banquet",
    // Bricolage
    "plombier", "electricien", "montage_meubles", "luminaire", "etagere",
    "electromenager", "carreleur", "plaquiste", "portail", "installation_tv",
    // Aide domicile
    "menage", "nettoyage_grand", "repassage", "courses", "cuisine_domicile",
    "aide_personne_agee", "aide_administrative", "gardiennage",
    "nettoyage_demenagement", "rangement",
    // Garde enfants
    "baby_sitter", "sortie_ecole", "garde_periscolaire", "garde_weekend",
    "garde_vacances", "garde_domicile",
    // Événementiel
    "dj", "dj_mariage", "sono", "animateur", "photographe", "videaste",
    "decoration_salle", "organisation_evenement",
    // Cours & soutien
    "soutien_primaire", "soutien_college", "soutien_lycee", "maths_physique",
    "francais_langues", "anglais", "espagnol", "informatique_cours",
    "musique", "coaching_sport", "concours",
    // Jardinage
    "tonte", "taille_haies", "debroussaillage", "desherbage", "elagage",
    "plantation", "potager",
    // Peinture
    "peintre", "peinture_facade", "peinture_portail", "enduit",
    "renovation_locative",
    // Main-d'oeuvre
    "demenageur", "manutention", "vigile", "distribution_flyers",
    "inventaire", "debarras", "stand",
    // Autre
    "informatique_depannage", "reseaux_sociaux", "nettoyage_vehicule",
    "coaching_perso", "traduction", "pet_sitting", "couture", "shooting_photo",
]);
const SYSTEM_PROMPT = `Tu es un classificateur de services à la personne pour la plateforme ilipresto.

Analyse cette image et identifie le service ou métier principal représenté.

Réponds UNIQUEMENT avec un objet JSON valide, sans texte avant ni après :
{"metier": "<clé>", "confidence": <nombre entre 0.0 et 1.0>}

ENUM FERMÉ — utilise exclusivement une de ces clés exactes :

Restauration : serveur, barman, plongeur, commis_cuisine, cuisinier, snack, food_truck, traiteur, banquet
Bricolage : plombier, electricien, montage_meubles, luminaire, etagere, electromenager, carreleur, plaquiste, portail, installation_tv
Aide domicile : menage, nettoyage_grand, repassage, courses, cuisine_domicile, aide_personne_agee, aide_administrative, gardiennage, nettoyage_demenagement, rangement
Garde enfants : baby_sitter, sortie_ecole, garde_periscolaire, garde_weekend, garde_vacances, garde_domicile
Événementiel : dj, dj_mariage, sono, animateur, photographe, videaste, decoration_salle, organisation_evenement
Cours : soutien_primaire, soutien_college, soutien_lycee, maths_physique, francais_langues, anglais, espagnol, informatique_cours, musique, coaching_sport, concours
Jardinage : tonte, taille_haies, debroussaillage, desherbage, elagage, plantation, potager
Peinture : peintre, peinture_facade, peinture_portail, enduit, renovation_locative
Main-d'oeuvre : demenageur, manutention, vigile, distribution_flyers, inventaire, debarras, stand
Autre : informatique_depannage, reseaux_sociaux, nettoyage_vehicule, coaching_perso, traduction, pet_sitting, couture, shooting_photo

Règles :
- Identifié clairement → confidence 0.7-1.0
- Ambiguë mais probable → confidence 0.4-0.69
- Aucun service reconnaissable → {"metier": null, "confidence": 0.0}
- NE génère PAS de catégorie ou sous-catégorie — uniquement la clé de l'enum`;
// ── Callable ───────────────────────────────────────────────────────────────────
exports.classifyServicePhoto = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.OPENAI_API_KEY],
    timeoutSeconds: 30,
    memory: "256MiB",
}, async (request) => {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const { imageUrl, imageBase64, mimeType } = request.data;
    if (!imageUrl && !imageBase64) {
        throw new https_1.HttpsError("invalid-argument", "Provide either imageUrl or imageBase64");
    }
    const imageContent = imageUrl
        ? { type: "image_url", image_url: { url: imageUrl, detail: "low" } }
        : {
            type: "image_url",
            image_url: {
                url: `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`,
                detail: "low",
            },
        };
    const openai = new openai_1.default({ apiKey: env_1.OPENAI_API_KEY.value() });
    let rawJson;
    try {
        const response = await openai.chat.completions.create({
            model: "gpt-4o-mini",
            max_tokens: 64,
            temperature: 0,
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                {
                    role: "user",
                    content: [imageContent],
                },
            ],
        });
        rawJson = response.choices[0]?.message?.content?.trim() ?? "";
    }
    catch (err) {
        logger_1.logger.error("classifyServicePhoto: OpenAI error", { uid, err });
        throw new https_1.HttpsError("internal", "Vision classification failed");
    }
    // Parse + validate
    let parsed;
    try {
        parsed = JSON.parse(rawJson);
    }
    catch {
        logger_1.logger.warn("classifyServicePhoto: unparseable response", { uid, rawJson });
        return { metier: null, confidence: 0 };
    }
    const metier = typeof parsed.metier === "string" && VALID_TRADE_KEYS.has(parsed.metier)
        ? parsed.metier
        : null;
    const confidence = typeof parsed.confidence === "number"
        ? Math.min(1, Math.max(0, parsed.confidence))
        : 0;
    logger_1.logger.info("classifyServicePhoto", { uid, metier, confidence });
    return { metier, confidence };
});
//# sourceMappingURL=classify_service_photo.js.map