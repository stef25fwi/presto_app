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

import OpenAI from "openai";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { COST_POLICY } from "../../../config/cost_policy";
import { OPENAI_API_KEY, ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { logger } from "../../../core/logger";
import { reserveMonthlyUsage } from "../../../shared/cost_quota";

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

// ── Types ──────────────────────────────────────────────────────────────────────

export interface ClassifyServicePhotoResult {
  metier: string | null;
  confidence: number;
}

// ── Callable ───────────────────────────────────────────────────────────────────

export const classifyServicePhoto = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request): Promise<ClassifyServicePhotoResult> => {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { imageUrl, imageBase64, mimeType } = request.data as {
      imageUrl?: string;
      imageBase64?: string;
      mimeType?: string;
    };

    if (!imageUrl && !imageBase64) {
      throw new HttpsError(
        "invalid-argument",
        "Provide either imageUrl or imageBase64"
      );
    }

    const imageContent: OpenAI.Chat.ChatCompletionContentPartImage =
      imageUrl
        ? { type: "image_url", image_url: { url: imageUrl, detail: "low" } }
        : {
            type: "image_url",
            image_url: {
              url: `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`,
              detail: "low",
            },
          };

    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });

    let rawJson: string;
    try {
      await reserveMonthlyUsage({
        metric: "openai_requests",
        units: 1,
        limit: COST_POLICY.openAiMonthlyRequestLimit,
      });
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
    } catch (err) {
      logger.error("classifyServicePhoto: OpenAI error", { uid, err });
      throw new HttpsError("internal", "Vision classification failed");
    }

    // Parse + validate
    let parsed: { metier: unknown; confidence: unknown };
    try {
      parsed = JSON.parse(rawJson);
    } catch {
      logger.warn("classifyServicePhoto: unparseable response", { uid, rawJson });
      return { metier: null, confidence: 0 };
    }

    const metier =
      typeof parsed.metier === "string" && VALID_TRADE_KEYS.has(parsed.metier)
        ? parsed.metier
        : null;

    const confidence =
      typeof parsed.confidence === "number"
        ? Math.min(1, Math.max(0, parsed.confidence))
        : 0;

    logger.info("classifyServicePhoto", { uid, metier, confidence });
    return { metier, confidence };
  }
);
