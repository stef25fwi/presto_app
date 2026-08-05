const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const functionsV1 = require("firebase-functions/v1");
const { defineSecret } = require('firebase-functions/params');
const admin = require('./lib/core/firebase_admin_compat');
const OpenAI = require('openai');
const { createModerateNewOffer } = require('./moderation');

const os = require('os');
const path = require('path');
const fs = require('fs/promises');
const { spawn } = require('child_process');
const ffmpegPath = require('ffmpeg-static');
const sharp = require('sharp');
const { randomUUID } = require('crypto');

admin.initializeApp();

const GCP_PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || '';
const IS_EMULATOR =
  process.env.FUNCTIONS_EMULATOR === 'true' ||
  Boolean(process.env.FIREBASE_EMULATOR_HUB);
const IS_PROD = GCP_PROJECT_ID === 'presto-app-74abe';
const rawSafeMode = String(process.env.APPCHECK_SAFE_MODE || '').toLowerCase() === 'true';
const rawEnforce = String(process.env.ENFORCE_APP_CHECK || '').toLowerCase();
const ENFORCE_APP_CHECK = IS_EMULATOR
  ? false
  : IS_PROD
    ? rawEnforce !== 'false' && !rawSafeMode
    : rawEnforce === 'true' && !rawSafeMode;

function assertProdSecurityConfig() {
  if (IS_PROD && !IS_EMULATOR && !ENFORCE_APP_CHECK) {
    console.error('CRITICAL_APP_CHECK_DISABLED', {
      projectId: GCP_PROJECT_ID,
      rawEnforce,
      rawSafeMode,
      emulator: IS_EMULATOR,
    });
  }
}

assertProdSecurityConfig();

const USER_STATS_DOC = admin.firestore().collection('_stats').doc('users');

// Secrets (Firebase Functions v2)
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
const GOOGLE_PLACES_API_KEY = defineSecret('GOOGLE_PLACES_API_KEY');
const PROJECT_REGION = process.env.FUNCTION_REGION || 'europe-west1';

// Carte des villes et codes postaux (Guadeloupe et Martinique)
const CITY_POSTAL_MAP = {
  // Guadeloupe
  'Baie-Mahault': '97122',
  'Les Abymes': '97139',
  'Pointe-à-Pitre': '97110',
  'Le Gosier': '97190',
  'Sainte-Anne': '97180',
  'Saint-François': '97118',
  'Petit-Bourg': '97170',
  'Lamentin': '97129',
  'Capesterre-Belle-Eau': '97130',
  'Basse-Terre': '97100',
  'Goyave': '97128',
  'Morne-à-l\'Eau': '97111',
  'Sainte-Rose': '97115',
  'Le Moule': '97160',
  'Saint-Claude': '97120',
  'Bouillante': '97125',
  'Deshaies': '97126',
  'Trois-Rivières': '97114',
  'Vieux-Habitants': '97119',
  'Vieux-Fort': '97141',
  'Anse-Bertrand': '97121',
  'Port-Louis': '97117',
  'Petit-Canal': '97131',
  'La Désirade': '97127',
  'Terre-de-Bas': '97136',
  'Terre-de-Haut': '97137',
  'Marie-Galante': '97140',
  // Martinique
  'Fort-de-France': '97200',
  'Le Lamentin': '97232',
  'Schoelcher': '97233',
  'Le Robert': '97231',
  'Le François': '97240',
  'Le Marin': '97290',
  'Les Trois-Îlets': '97229',
  'Sainte-Luce': '97228',
  'Sainte-Anne (MQ)': '97227',
  'La Trinité': '97220',
  'Le Lorrain': '97214',
  'Le Carbet': '97221',
  'Le Diamant': '97223',
  'Saint-Esprit': '97270',
};

/**
 * Recherche le code postal à partir du nom de la ville
 * Gère les variations de casse et les accents
 */
function findPostalCode(cityName) {
  if (!cityName) return '';
  
  // Normaliser le nom de la ville (enlever accents, casse insensible)
  // Mais garder la structure (tirets, espaces) pour améliorer le matching
  const normalize = (str) => str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')  // Enlever accents
    .replace(/\s+/g, ' ')  // Normaliser les espaces multiples
    .trim();
  
  const normalizedInput = normalize(cityName);
  
  // Recherche exacte d'abord (avec tirets ou espaces)
  for (const [city, postal] of Object.entries(CITY_POSTAL_MAP)) {
    const normalizedCity = normalize(city);
    if (normalizedCity === normalizedInput) {
      console.log(`[findPostalCode] Match exact: "${cityName}" -> "${city}" = ${postal}`);
      return postal;
    }
  }
  
  // Recherche avec variantes (tirets vs espaces)
  const withDashes = normalizedInput.replace(/\s+/g, '-');
  const withSpaces = normalizedInput.replace(/-/g, ' ');
  
  for (const [city, postal] of Object.entries(CITY_POSTAL_MAP)) {
    const normalizedCity = normalize(city);
    const cityWithDashes = normalizedCity.replace(/\s+/g, '-');
    const cityWithSpaces = normalizedCity.replace(/-/g, ' ');
    
    if (cityWithDashes === withDashes || cityWithSpaces === withSpaces) {
      console.log(`[findPostalCode] Match variante: "${cityName}" -> "${city}" = ${postal}`);
      return postal;
    }
  }
  
  // Recherche partielle si pas de correspondance exacte
  for (const [city, postal] of Object.entries(CITY_POSTAL_MAP)) {
    const normalizedCity = normalize(city);
    if (normalizedCity.includes(normalizedInput) || normalizedInput.includes(normalizedCity)) {
      console.log(`[findPostalCode] Match partiel: "${cityName}" -> "${city}" = ${postal}`);
      return postal;
    }
  }
  
  console.log(`[findPostalCode] Aucun match pour: "${cityName}" (normalise: "${normalizedInput}")`);
  return '';
}

/**
 * Prétraite le texte transcrit pour corriger les erreurs communes
 * de reconnaissance vocale française.
 * IMPORTANT : ne met PAS en lowercase — Google STT renvoie du texte
 * correctement casé qu'OpenAI exploite mieux tel quel.
 */
function preprocessTranscript(text) {
  if (!text) return '';
  
  let cleaned = text.trim();
  
  // Corrections communes pour les villes des Antilles (case-insensitive)
  const cityCorrections = {
    'baie ma haut': 'Baie-Mahault',
    'baie mahaut': 'Baie-Mahault',
    'bye mahaut': 'Baie-Mahault',
    'les zabîmes': 'Les Abymes',
    'les abîmes': 'Les Abymes',
    'pointe à pitre': 'Pointe-à-Pitre',
    'fort de france': 'Fort-de-France',
    'le lamentin': 'Le Lamentin',
    'petit bourg': 'Petit-Bourg',
    'le gosier': 'Le Gosier',
    'sainte anne': 'Sainte-Anne',
    'saint françois': 'Saint-François',
  };
  
  for (const [wrong, correct] of Object.entries(cityCorrections)) {
    cleaned = cleaned.replace(new RegExp(wrong, 'gi'), correct);
  }
  
  return cleaned;
}

function parseGsUri(gcsUri) {
  if (typeof gcsUri !== 'string') return null;
  const s = gcsUri.trim();
  if (!s.startsWith('gs://')) return null;
  const rest = s.slice('gs://'.length);
  const slash = rest.indexOf('/');
  if (slash <= 0) return null;
  const bucket = rest.slice(0, slash);
  const object = rest.slice(slash + 1);
  if (!bucket || !object) return null;
  if (object.includes('..') || object.startsWith('/') || object.includes('\\')) return null;
  return { bucket, object };
}

// ============================================================================
// Google Places proxy (évite d'exposer la clé côté client)
// ============================================================================

function assertAuthenticated(req) {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return uid;
}

function asNonEmptyString(v) {
  if (typeof v !== 'string') return null;
  const s = v.trim();
  return s ? s : null;
}

async function rateLimitOrThrow({ uid, action, limit, windowSec }) {
  const now = Date.now();
  const bucket = Math.floor(now / (windowSec * 1000));
  const id = `${action}_${uid}_${bucket}`;

  const ref = admin.firestore().collection('_rate_limits').doc(id);
  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const prev = snap.exists ? Number(snap.data()?.count || 0) : 0;
    const next = prev + 1;
    if (next > limit) {
      throw new HttpsError('resource-exhausted', 'Trop de requêtes. Réessaie dans quelques instants.');
    }

    const expiresAtMs = (bucket + 1) * windowSec * 1000;
    tx.set(
      ref,
      {
        uid,
        action,
        bucket,
        count: next,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
      },
      { merge: true }
    );
  });
}

exports.placesAutocomplete = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 15,
    secrets: [GOOGLE_PLACES_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    const uid = assertAuthenticated(req);
    await rateLimitOrThrow({ uid, action: 'places_autocomplete', limit: 30, windowSec: 60 });

    const input = asNonEmptyString(req.data?.input);
    if (!input) throw new HttpsError('invalid-argument', 'input manquant');
    if (input.length > 120) throw new HttpsError('invalid-argument', 'input trop long');

    const language = asNonEmptyString(req.data?.language) || 'fr';
    const types = asNonEmptyString(req.data?.types);

    // componentRestrictions: { country: 'fr' } etc.
    const componentRestrictions = req.data?.componentRestrictions;
    let components = null;
    if (componentRestrictions && typeof componentRestrictions === 'object') {
      const entries = Object.entries(componentRestrictions)
        .filter(([k, v]) => typeof k === 'string' && typeof v === 'string' && k.trim() && v.trim())
        .slice(0, 5)
        .map(([k, v]) => `${k}:${v}`)
        .join('|');
      components = entries || null;
    }

    const apiKey = GOOGLE_PLACES_API_KEY.value();
    if (!apiKey) throw new HttpsError('failed-precondition', 'GOOGLE_PLACES_API_KEY manquante');

    const url = new URL('https://maps.googleapis.com/maps/api/place/autocomplete/json');
    url.searchParams.set('input', input);
    url.searchParams.set('language', language);
    url.searchParams.set('key', apiKey);
    if (types) url.searchParams.set('types', types);
    if (components) url.searchParams.set('components', components);

    const resp = await fetch(url.toString(), { method: 'GET' });
    const data = await resp.json().catch(() => null);
    if (!resp.ok || !data) {
      throw new HttpsError('internal', 'Erreur Google Places (autocomplete)');
    }

    const status = String(data.status || '');
    if (status !== 'OK' && status !== 'ZERO_RESULTS') {
      console.warn('[placesAutocomplete] non-OK status', { status, uid });
      throw new HttpsError('failed-precondition', `Places: ${status}`);
    }

    const predictions = Array.isArray(data.predictions) ? data.predictions : [];
    return {
      status,
      predictions: predictions.map((item) => ({
        description: String(item?.description || ''),
        placeId: String(item?.place_id || ''),
      })),
    };
  }
);

exports.placesDetails = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 15,
    secrets: [GOOGLE_PLACES_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    const uid = assertAuthenticated(req);
    await rateLimitOrThrow({ uid, action: 'places_details', limit: 30, windowSec: 60 });

    const placeId = asNonEmptyString(req.data?.placeId);
    if (!placeId) throw new HttpsError('invalid-argument', 'placeId manquant');
    if (placeId.length > 200) throw new HttpsError('invalid-argument', 'placeId trop long');

    const language = asNonEmptyString(req.data?.language) || 'fr';

    const apiKey = GOOGLE_PLACES_API_KEY.value();
    if (!apiKey) throw new HttpsError('failed-precondition', 'GOOGLE_PLACES_API_KEY manquante');

    const url = new URL('https://maps.googleapis.com/maps/api/place/details/json');
    url.searchParams.set('place_id', placeId);
    url.searchParams.set('fields', 'address_components');
    url.searchParams.set('language', language);
    url.searchParams.set('key', apiKey);

    const resp = await fetch(url.toString(), { method: 'GET' });
    const data = await resp.json().catch(() => null);
    if (!resp.ok || !data) {
      throw new HttpsError('internal', 'Erreur Google Places (details)');
    }

    const status = String(data.status || '');
    if (status !== 'OK') {
      console.warn('[placesDetails] non-OK status', { status, uid });
      throw new HttpsError('failed-precondition', `Places: ${status}`);
    }

    return {
      status,
      result: data.result || null,
    };
  }
);

// ============================================================================
// Core draft generation logic (shared by generateOfferDraft + microIaProcessAudio)
// ============================================================================

const DRAFT_SYSTEM_PROMPT = `Tu es un assistant rédactionnel pour l'application Prestō.
Ta mission : transformer un besoin utilisateur souvent dicté à l'oral en brouillon d'annonce exploitable immédiatement dans le formulaire.

Contrainte absolue : tu renvoies UNIQUEMENT un JSON valide. Aucun markdown, aucun commentaire, aucun texte avant ou après le JSON.

Priorité des sources si plusieurs blocs sont fournis :
1. "Transcription vocale"
2. "Précisions utilisateur"
3. "Description actuelle"

Règles de production :
- N'invente jamais d'informations absentes ou ambiguës. Si une donnée manque, mets null ou [].
- Corrige les fautes, enlève les hésitations, fusionne les répétitions, mais conserve le sens métier exact.
- Le texte doit rester fidèle à la transcription source. Tu reformules légèrement pour clarifier, mais tu n'ajoutes aucun détail, aucune contrainte ou aucune précision non explicitement dite.
- Le titre doit être court, clair, spécifique, sans ponctuation marketing, idéalement entre 25 et 60 caractères.
- "description_courte" doit être une retranscription nettoyée et publiable des faits explicitement mentionnés, en 1 à 3 phrases maximum, sans extrapolation.
- "details" ne doit contenir QUE des informations complémentaires ABSENTES de "description_courte" (contrainte technique, matériel fourni, précision d'accès, référence produit…). Il est INTERDIT d'y reformuler, résumer ou répéter une information déjà présente dans "description_courte" ou la transcription. Si aucune information nouvelle à ajouter, renvoie []. Maximum 4 items, un item par idée.
- Ne produis PAS de budget, d'urgence ni de disponibilités : l'utilisateur remplit ces champs manuellement dans le formulaire.

Règle d'extraction :
- Ville : reprends la ville mentionnée dans l'entrée. Si elle n'apparaît pas clairement mais qu'une ville de contexte est fournie, tu peux reprendre cette ville de contexte.

Catégorie et sous-catégorie : choisis uniquement parmi cette liste si c'est suffisamment clair, sinon null.
- Jardinage → sous-cats: Tonte de pelouse, Taille de haies, Débroussaillage, Désherbage / nettoyage massif, Élagage léger, Création de massifs / plantations, Arrosage / entretien régulier, Évacuation des végétaux, Entretien jardin location, Entretien potager
- Bricolage / Travaux → sous-cats: Montage de meubles, Pose de luminaires, Pose de tringles / étagères, Réparation électroménager, Petits travaux électricité, Petits travaux plomberie, Pose de cloison / placo, Pose de carrelage / faïence, Réparation portail / clôture, Installation TV / support mural
- Aide à domicile → sous-cats: Ménage régulier, Ménage ponctuel / grand nettoyage, Repassage, Aide aux courses, Préparation des repas, Accompagnement personnes âgées, Aide administrative / papiers, Gardiennage maison (absence), Nettoyage après déménagement, Organisation / rangement
- Restauration / Extra → sous-cats: Service en salle, Bar / Barman, Plonge / Vaisselle, Aide cuisine / Commis, Chef de partie / Cuisinier, Snack / Fast-food, Food truck / Événementiel, Petit-déjeuner / Brunch, Service banquet / Mariage, Traiteur à domicile
- Événementiel / DJ → sous-cats: DJ soirée privée, DJ mariage, DJ anniversaire, Location sono / lumières, Animateur micro / MC, Photographe événement, Vidéaste événement, Serveur / barman événementiel, Décoration de salle, Organisation complète événement
- Garde d'enfants → sous-cats: Baby-sitting soirée, Sortie d'école / crèche, Garde périscolaire, Garde week-end, Garde vacances scolaires, Garde occasionnelle urgence, Garde à domicile temps plein, Garde partagée, Accompagnement activités, Aide aux devoirs légère
- Cours & soutien → sous-cats: Aide aux devoirs primaire, Soutien collège, Soutien lycée, Maths / Physique, Français / Langues, Anglais, Espagnol, Initiation informatique, Cours de musique, Coaching sport / fitness, Préparation examens / concours
- Peinture → sous-cats: Peinture chambre / salon, Peinture façade, Peinture grille / portail, Préparation murs (enduit, ponçage), Rafraîchissement appartement, Peinture boiseries, Peinture plafond, Peinture escalier / cage, Peinture décorative, Rénovation locative express
- Main-d'œuvre → sous-cats: Aide déménagement, Chargement / déchargement, Port de charges lourdes, Manutention chantier, Montage / démontage stands, Manutention événementielle, Distribution flyers / échantillons, Inventaire magasin, Aide livraison, Aide débarras / encombrants
- Autre → sous-cats: Informatique / dépannage, Réseaux sociaux / contenu, Nettoyage véhicule, Aide administrative / comptable, Coaching perso / pro, Traduction, Promenade animaux / pet-sitting, Couture / retouches, Assistance shooting photo

FORMAT JSON OBLIGATOIRE :
{
  "titre": string,
  "categorie": string|null,
  "sous_categorie": string|null,
  "ville": string|null,
  "description_courte": string,
  "details": [string]
}`;

async function _internalGenerateDraft({ openai, hint, city, category, lang, model }) {
  const userPrompt = `Contenu utilisateur à restructurer :
${hint}

Contexte disponible :
- Ville de contexte : ${city || 'Non détectée'}
- Catégorie de contexte : ${category || 'Non spécifiée'}
- Langue : ${lang || 'fr'}

Retourne uniquement le JSON demandé.`;

  const completion = await openai.chat.completions.create({
    model: model || 'gpt-4o-mini',
    messages: [
      { role: 'system', content: DRAFT_SYSTEM_PROMPT },
      { role: 'user', content: userPrompt }
    ],
    temperature: 0.2,
    // Schéma allégé (titre/catégorie/ville/description/details uniquement) :
    // ~150 tokens de sortie suffisent, et chaque token coûte ~13 ms de latence.
    max_tokens: 180,
    response_format: { type: 'json_object' },
  });

  const aiResponse = completion.choices?.[0]?.message?.content?.trim();
  if (!aiResponse) {
    throw new Error('Pas de réponse de OpenAI');
  }

  let draft;
  try {
    let cleaned = aiResponse;
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }
    draft = JSON.parse(cleaned);
  } catch (e) {
    console.warn('[_internalGenerateDraft] JSON parse failed, using fallback:', e.message);
    draft = {
      titre: 'Nouvelle demande',
      description_courte: `Je recherche: ${hint.substring(0, 200)}`,
      categorie: category || null,
      ville: city || null,
      details: [],
    };
  }

  if (!draft.titre && !draft.title) {
    throw new Error('Réponse IA invalide : titre manquant');
  }

  const finalCity = draft.ville || city || '';
  let finalPostalCode = '';
  if (finalCity && !draft.postalCode) {
    finalPostalCode = findPostalCode(finalCity);
  } else {
    finalPostalCode = draft.postalCode || '';
  }

  // Les champs budget/urgence/disponibilités (et annexes) ne sont plus
  // générés par l'IA — l'utilisateur les remplit manuellement. On renvoie
  // des valeurs neutres pour rester compatible avec les clients existants.
  return {
    title: draft.titre || draft.title || '',
    description: draft.description_courte || draft.description || '',
    category: draft.categorie || category || 'Autre',
    city: finalCity,
    postalCode: finalPostalCode,
    titre: draft.titre || draft.title || '',
    suggestions_titres: [],
    description_courte: draft.description_courte || draft.description || '',
    categorie: draft.categorie || category || null,
    sous_categorie: draft.sous_categorie || null,
    ville: finalCity,
    secteur: null,
    budget: { type: null, min: null, max: null, devise: 'EUR' },
    urgence: null,
    details: draft.details || [],
    competences_requises: [],
    materiel: { fourni_par_demandeur: [], a_prevoir_par_prestataire: [] },
    disponibilites: null,
    questions_a_poser: []
  };
}

const LISTING_AI_SYSTEM_PROMPT = `Tu es l'assistant OpenAI de l'application Prestō.
Tu extrais un brouillon d'annonce structuré à partir d'un texte utilisateur libre ou d'une transcription audio.

Règles absolues :
- Tu renvoies uniquement un JSON strict conforme au schéma fourni.
- Tu n'inventes aucune information absente.
- Si une donnée n'est pas clairement présente, utilise null, [] ou une faible confiance.
- Tu peux utiliser la ville ou la catégorie de contexte uniquement comme fallback prudent.
- Le champ description doit être publiable, fidèle et concis.
- keywords doit contenir des mots-clés courts réellement présents ou implicites avec forte certitude.
- missingFields doit contenir uniquement les champs encore utiles pour finaliser la publication.
- confidenceScore est une valeur entre 0 et 1.`;

const LISTING_AI_RESPONSE_FORMAT = {
  type: 'json_schema',
  json_schema: {
    name: 'listing_ai_result',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        title: { type: ['string', 'null'] },
        category: { type: ['string', 'null'] },
        description: { type: ['string', 'null'] },
        price: { type: ['number', 'null'] },
        currency: { type: ['string', 'null'] },
        city: { type: ['string', 'null'] },
        department: { type: ['string', 'null'] },
        postalCode: { type: ['string', 'null'] },
        listingType: { type: ['string', 'null'] },
        urgency: { type: ['string', 'null'] },
        contactPreference: { type: ['string', 'null'] },
        keywords: {
          type: 'array',
          items: { type: 'string' },
        },
        details: {
          type: 'array',
          items: { type: 'string' },
        },
        missingFields: {
          type: 'array',
          items: { type: 'string' },
        },
        confidenceScore: { type: ['number', 'null'] },
        questionsToAsk: {
          type: 'array',
          items: { type: 'string' },
        },
      },
      required: [
        'title',
        'category',
        'description',
        'price',
        'currency',
        'city',
        'department',
        'postalCode',
        'listingType',
        'urgency',
        'contactPreference',
        'keywords',
        'details',
        'missingFields',
        'confidenceScore',
        'questionsToAsk',
      ],
    },
  },
};

function nullableTrimmedString(value) {
  if (value == null) return null;
  const text = String(value).trim();
  return text ? text : null;
}

function stringListOrEmpty(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item || '').trim())
    .filter((item) => item.length > 0);
}

function normalizeListingDepartment(postalCode, city) {
  const cp = nullableTrimmedString(postalCode);
  if (cp && /^\d{5}$/.test(cp)) {
    if (cp.startsWith('97') || cp.startsWith('98')) {
      return cp.slice(0, 3);
    }
    return cp.slice(0, 2);
  }

  const fallbackPostalCode = findPostalCode(city);
  if (!fallbackPostalCode) return null;
  if (fallbackPostalCode.startsWith('97') || fallbackPostalCode.startsWith('98')) {
    return fallbackPostalCode.slice(0, 3);
  }
  return fallbackPostalCode.slice(0, 2);
}

function computeListingMissingFields(result) {
  const missing = new Set(stringListOrEmpty(result?.missingFields));

  if (!result?.title) missing.add('title');
  if (!result?.description) missing.add('description');
  if (!result?.category) missing.add('category');
  if (!result?.city) missing.add('city');
  if (!result?.postalCode) missing.add('postalCode');

  return Array.from(missing);
}

function computeListingConfidenceScore(result) {
  const raw = Number(result?.confidenceScore);
  if (Number.isFinite(raw)) {
    return Math.max(0, Math.min(1, raw));
  }

  const weightedSignals = [
    result?.title ? 1 : 0,
    result?.description ? 1 : 0,
    result?.category ? 1 : 0,
    result?.city ? 1 : 0,
    result?.postalCode ? 1 : 0,
    typeof result?.price === 'number' ? 1 : 0,
  ];
  const score = weightedSignals.reduce((sum, value) => sum + value, 0) / weightedSignals.length;
  return Number(score.toFixed(2));
}

function normalizeListingAiResult(raw, { city, category }) {
  const normalizedTitle = nullableTrimmedString(raw?.title);
  const normalizedDescription = nullableTrimmedString(raw?.description);
  const normalizedCategory = nullableTrimmedString(raw?.category) || nullableTrimmedString(category);
  const normalizedCity = nullableTrimmedString(raw?.city) || nullableTrimmedString(city);
  const detectedPostalCode = nullableTrimmedString(raw?.postalCode) || findPostalCode(normalizedCity);
  const detectedDepartment = nullableTrimmedString(raw?.department) || normalizeListingDepartment(detectedPostalCode, normalizedCity);
  const normalizedCurrency = (nullableTrimmedString(raw?.currency) || 'EUR').toUpperCase();
  const rawPrice = raw?.price;
  const normalizedPrice = typeof rawPrice === 'number'
    ? rawPrice
    : (typeof rawPrice === 'string' ? Number(rawPrice) : null);

  const result = {
    title: normalizedTitle || '',
    category: normalizedCategory,
    description: normalizedDescription || '',
    price: Number.isFinite(normalizedPrice) ? normalizedPrice : null,
    currency: normalizedCurrency,
    city: normalizedCity,
    department: detectedDepartment,
    postalCode: detectedPostalCode || null,
    listingType: nullableTrimmedString(raw?.listingType),
    urgency: nullableTrimmedString(raw?.urgency),
    contactPreference: nullableTrimmedString(raw?.contactPreference),
    keywords: stringListOrEmpty(raw?.keywords),
    details: stringListOrEmpty(raw?.details),
    missingFields: [],
    confidenceScore: null,
    questionsToAsk: stringListOrEmpty(raw?.questionsToAsk),
  };

  result.missingFields = computeListingMissingFields(result);
  result.confidenceScore = computeListingConfidenceScore({
    ...result,
    confidenceScore: raw?.confidenceScore,
  });

  return result;
}

async function _internalExtractListingFieldsWithOpenAi({ openai, input, city, category, languageCode }) {
  const userPrompt = `Texte source :\n${input}\n\nContexte :\n- Ville: ${city || 'non précisée'}\n- Catégorie: ${category || 'non précisée'}\n- Langue: ${languageCode || 'fr-FR'}\n\nExtrais uniquement les informations utiles pour préremplir une annonce.`;

  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    temperature: 0.1,
    max_tokens: 700,
    response_format: LISTING_AI_RESPONSE_FORMAT,
    messages: [
      { role: 'system', content: LISTING_AI_SYSTEM_PROMPT },
      { role: 'user', content: userPrompt },
    ],
  });

  const content = completion?.choices?.[0]?.message?.content?.trim();
  if (!content) {
    throw new Error('Pas de réponse structurée de OpenAI');
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (error) {
    throw new Error(`Réponse OpenAI invalide: ${error?.message || error}`);
  }

  return normalizeListingAiResult(parsed, { city, category });
}

/**
 * Cloud Function qui génère un brouillon d'offre avec l'IA
 * 
 * Entrée : { hint, city, category, lang }
 * Sortie : { title, description, category, city, postalCode }
 */
exports.generateOfferDraft = onCall({ region: PROJECT_REGION, timeoutSeconds: 60, secrets: [OPENAI_API_KEY], enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  // 🔒 Auth requise (y compris auth anonyme côté app)
  const uid = assertAuthenticated(request);

  // 🔒 Rate limiting: 15 appels / 60s par utilisateur
  await rateLimitOrThrow({ uid, action: 'generate_offer_draft', limit: 15, windowSec: 60 });

  let { hint, city, category, lang = 'fr' } = request.data;

  hint = preprocessTranscript(hint);

  if (!hint || typeof hint !== 'string' || hint.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Le paramètre "hint" est requis');
  }

  const apiKey = OPENAI_API_KEY.value();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'OPENAI_API_KEY manquante');
  }
  const openai = new OpenAI({ apiKey });

  try {
    return await _internalGenerateDraft({ openai, hint, city, category, lang });
  } catch (error) {
    console.error('Erreur generateOfferDraft:', error?.message || error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', `Erreur IA : ${error.message}`);
  }
});

exports.openAiExtractListingFields = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 45,
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request) => {
    const uid = assertAuthenticated(request);
    await rateLimitOrThrow({ uid, action: 'openai_extract_listing_fields', limit: 15, windowSec: 60 });

    const input = preprocessTranscript(String(request.data?.input || request.data?.hint || '').trim());
    const city = nullableTrimmedString(request.data?.city) || '';
    const category = nullableTrimmedString(request.data?.category) || '';
    const languageCode = nullableTrimmedString(request.data?.languageCode) || 'fr-FR';

    if (!input) {
      throw new HttpsError('invalid-argument', 'Le champ input est requis');
    }

    const apiKey = OPENAI_API_KEY.value();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY manquante');
    }

    const openai = new OpenAI({ apiKey });

    try {
      const result = await _internalExtractListingFieldsWithOpenAi({
        openai,
        input,
        city,
        category,
        languageCode,
      });
      return { result };
    } catch (error) {
      console.error('[openAiExtractListingFields] Error:', error?.message || error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', error?.message || 'openAiExtractListingFields failed');
    }
  }
);

// [REMOVED] transcribeAndDraftOffer — orphaned, replaced by microIaProcessAudio combined mode.
// See microIaProcessAudio with generateDraft=true.

// =====================================================
// Micro-IA Router: HYBRID / GOOGLE_ONLY / WHISPER_ONLY
// StoragePath in Firebase Storage: "stt/uid_timestamp.wav"
// =====================================================

const speech = require("@google-cloud/speech");

// Clients lourds réutilisés entre invocations : évite de réétablir le canal
// gRPC (Speech) / le handshake TLS (OpenAI) à CHAQUE appel, ce qui coûtait
// plusieurs secondes sur le chemin chaud micro-IA.
let _speechClientSingleton = null;
function getSpeechClient() {
  return (_speechClientSingleton ||= new speech.SpeechClient());
}
let _openAiSingleton = null;
function getOpenAiClient() {
  return (_openAiSingleton ||= new OpenAI({ apiKey: OPENAI_API_KEY.value() }));
}
const { toFile } = require("openai");

exports.moderateNewOffer = createModerateNewOffer({
  admin,
  onDocumentCreated,
  region: PROJECT_REGION,
});

// Assure-toi que initializeApp est appelé une seule fois dans ton fichier
// if (admin.apps.length === 0) admin.initializeApp();

function normalizeMode(mode) {
  const m = (mode || "").toUpperCase();
  if (["HYBRID", "GOOGLE_ONLY", "WHISPER_ONLY"].includes(m)) return m;
  return "HYBRID";
}

function normalizeAudioQuality(v) {
  const s = String(v || '').trim().toUpperCase();
  if (s === 'LOW' || s === 'MEDIUM' || s === 'HIGH') return s;
  return 'MEDIUM';
}

function normalizeUltraFastEnabled(v) {
  return asBool(v, false);
}

// ---------- Remote Config cache (évite de fetch à chaque appel) ----------
let _microIaCfgCache = null;
let _microIaCfgCacheAt = 0;
const MICROIA_RC_CACHE_MS = 60 * 1000; // 60s

function asBool(v, def) {
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return v.toLowerCase() === "true";
  return def;
}
function asNum(v, def) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : def;
}

async function getMicroIaConfig({ forceRefresh = false } = {}) {
  const now = Date.now();
  if (!forceRefresh && _microIaCfgCache && (now - _microIaCfgCacheAt) < MICROIA_RC_CACHE_MS) {
    return _microIaCfgCache;
  }

  try {
    const tpl = await admin.remoteConfig().getTemplate();
    const p = tpl.parameters || {};

    const mode = normalizeMode(p.microia_mode?.defaultValue?.value || "GOOGLE_ONLY");
    const fallbackEnabled = asBool(p.microia_fallback_enabled?.defaultValue?.value, true);
    const qualityThreshold = asNum(p.microia_quality_threshold?.defaultValue?.value, 0.62);
    const languageCode = p.microia_language_code?.defaultValue?.value || "fr-FR";
    const audioQuality = normalizeAudioQuality(p.microia_audio_quality?.defaultValue?.value || 'MEDIUM');
    const ultraFastEnabled = normalizeUltraFastEnabled(
      p.microia_ultra_fast_enabled?.defaultValue?.value ||
        p.microia_ultrafast_enabled?.defaultValue?.value ||
        p.microia_ultra_fast?.defaultValue?.value ||
        false
    );
    // Modèle OpenAI du draft, ajustable sans redéploiement (test latence).
    const draftModel = String(p.microia_draft_model?.defaultValue?.value || '').trim() || 'gpt-4o-mini';

    _microIaCfgCache = { mode, fallbackEnabled, qualityThreshold, languageCode, audioQuality, ultraFastEnabled, draftModel };
    _microIaCfgCacheAt = now;
    return _microIaCfgCache;
  } catch (e) {
    console.warn("[getMicroIaConfig] Remote Config fetch failed, using defaults:", e?.message || e);
    _microIaCfgCache = { mode: "GOOGLE_ONLY", fallbackEnabled: true, qualityThreshold: 0.62, languageCode: "fr-FR", audioQuality: 'MEDIUM', ultraFastEnabled: false, draftModel: 'gpt-4o-mini' };
    _microIaCfgCacheAt = now;
    return _microIaCfgCache;
  }
}

function evaluateQuality({ text, googleConfidence, audioInfo }) {
  const t = (text || "").trim();
  const reasons = [];

  if (!t) reasons.push("empty");
  if (t.length < 12) reasons.push("too_short");
  if (/\b(inaudible|incompréhensible|\.\.\.)\b/i.test(t)) reasons.push("noisy_tokens");

  // Si l'audio est "long" mais le texte est très court, la qualité est probablement mauvaise.
  const dataBytes = typeof audioInfo?.dataBytes === 'number' ? audioInfo.dataBytes : null;
  if (dataBytes != null && dataBytes > 0) {
    const sampleRate = typeof audioInfo?.sampleRate === 'number' && audioInfo.sampleRate > 0 ? audioInfo.sampleRate : 16000;
    const numChannels = typeof audioInfo?.numChannels === 'number' && audioInfo.numChannels > 0 ? audioInfo.numChannels : 1;
    const bitsPerSample = typeof audioInfo?.bitsPerSample === 'number' && audioInfo.bitsPerSample > 0 ? audioInfo.bitsPerSample : 16;
    const bytesPerSecond = sampleRate * numChannels * (bitsPerSample / 8);
    const durationSec = bytesPerSecond > 0 ? (dataBytes / bytesPerSecond) : null;

    if (typeof durationSec === 'number' && Number.isFinite(durationSec)) {
      const shortForAudio =
        (durationSec >= 2 && t.length < 8) ||
        (durationSec >= 4 && t.length < 20) ||
        (durationSec >= 8 && t.length < 50);
      if (shortForAudio) reasons.push('short_text_for_audio');
    }
  }

  let score = 0.0;
  if (t.length >= 12) score += 0.25;
  if (t.length >= 30) score += 0.25;
  if (t.length >= 80) score += 0.15;

  if (typeof googleConfidence === "number") {
    if (googleConfidence >= 0.75) {
      score += 0.25;
    } else if (googleConfidence >= 0.60) {
      score += 0.15;
    } else {
      reasons.push("low_confidence");
      // ✅ pénalité : sinon du texte long mais faux peut "passer"
      score -= 0.15;
    }
  } else {
    // Whisper-only n'a souvent pas de confidence → on reste prudent
    score += 0.05;
  }

  if (reasons.includes("noisy_tokens")) score -= 0.20;
  if (reasons.includes("too_short")) score -= 0.15;
  if (reasons.includes('short_text_for_audio')) score -= 0.25;
  if (reasons.includes("empty")) score = 0.0;

  score = Math.max(0, Math.min(1, score));
  return { score, reasons };
}

function normalizeRoleValues(rawRoles) {
  const values = Array.isArray(rawRoles)
    ? rawRoles
    : typeof rawRoles === 'string'
      ? rawRoles.split(/[\s,]+/)
      : rawRoles instanceof Set
        ? Array.from(rawRoles)
        : [];

  return values
    .map((role) => String(role || '').trim().toLowerCase())
    .filter(Boolean);
}

function hasAdminRoleData(data) {
  if (!data || typeof data !== 'object') {
    return false;
  }

  const roles = normalizeRoleValues(data.roles);
  const primaryRole = String(data.primaryRole || '').trim().toLowerCase();

  return (
    roles.includes('admin') ||
    roles.includes('superadmin') ||
    primaryRole === 'admin' ||
    primaryRole === 'superadmin' ||
    data.admin === true ||
    data.superadmin === true
  );
}

function extractBearerTokenFromCallableRequest(req) {
  const authHeader =
    req?.rawRequest?.headers?.authorization ||
    req?.rawRequest?.headers?.Authorization ||
    null;

  if (typeof authHeader !== 'string') {
    return null;
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return null;
  }

  const token = String(match[1] || '').trim();
  return token || null;
}

async function resolveCallableAuthContext(req) {
  const requestUid = String(req?.auth?.uid || '').trim();
  if (requestUid) {
    return {
      uid: requestUid,
      token: req?.auth?.token || {},
      source: 'request.auth',
    };
  }

  const bearerToken = extractBearerTokenFromCallableRequest(req);
  if (!bearerToken) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  try {
    const decoded = await admin.auth().verifyIdToken(bearerToken);
    const decodedUid = String(decoded?.uid || decoded?.sub || '').trim();
    if (!decodedUid) {
      throw new Error('Decoded token without uid');
    }

    return {
      uid: decodedUid,
      token: decoded || {},
      source: 'authorization-bearer',
    };
  } catch (error) {
    console.error('[admin-auth-probe]', {
      label: 'resolveCallableAuthContext:verifyIdToken-failed',
      code: error?.code || null,
      message: error?.message || String(error),
    });
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
}

function adminAuthProbe(label, req, extra = {}) {
  const authHeader =
    req?.rawRequest?.headers?.authorization ||
    req?.rawRequest?.headers?.Authorization ||
    null;
  const token = req?.auth?.token || {};
  const tokenRoles = normalizeRoleValues(token.roles);
  const tokenPrimaryRole = String(token.primaryRole || '').trim().toLowerCase() || null;

  console.log('[admin-auth-probe]', {
    label,
    project: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || null,
    region: PROJECT_REGION,
    callType: 'callable',
    authPresent: Boolean(req?.auth),
    uid: req?.auth?.uid || null,
    email: token.email || null,
    tokenHasAdmin: hasAdminRoleData(token),
    tokenRoles,
    tokenPrimaryRole,
    hasAuthorizationHeader: Boolean(authHeader),
    authorizationPrefix:
      typeof authHeader === 'string' ? authHeader.slice(0, 12) : null,
    appCheckPresent: Boolean(req?.app),
    appCheckAppId: req?.app?.appId || req?.app?.app_id || null,
    ...extra,
  });
}

async function resolveAdminAccess(req) {
  adminAuthProbe('resolveAdminAccess:start', req);

  let authContext;
  try {
    authContext = await resolveCallableAuthContext(req);
  } catch (error) {
    adminAuthProbe('resolveAdminAccess:unauthenticated', req, {
      reason: 'missing_auth_uid',
    });
    throw error;
  }

  const uid = authContext.uid;
  const token = authContext.token || {};

  const tokenRoles = normalizeRoleValues(token.roles);
  const tokenHasAdmin = hasAdminRoleData(token);

  const [userSnap, adminSnap] = await Promise.all([
    admin.firestore().collection('users').doc(uid).get(),
    admin.firestore().collection('admins').doc(uid).get(),
  ]);
  const userData = userSnap.data() || {};
  const userRoles = normalizeRoleValues(userData.roles);
  const userPrimaryRole = String(userData.primaryRole || '').trim().toLowerCase();
  const userHasAdmin = hasAdminRoleData(userData);

  const adminData = adminSnap.data() || {};
  const adminDocEnabled = adminSnap.exists && adminData.enabled !== false;

  const debug = {
    authSource: authContext.source,
    tokenHasAdmin,
    tokenRoles,
    userDocExists: userSnap.exists,
    userHasAdmin,
    userRoles,
    userPrimaryRole: userPrimaryRole || null,
    userAdminFlag: userData.admin === true,
    userSuperadminFlag: userData.superadmin === true,
    adminDocExists: adminSnap.exists,
    adminDocEnabled,
  };

  if (tokenHasAdmin) {
    adminAuthProbe('resolveAdminAccess:granted', req, {
      authSource: authContext.source,
      source: 'token',
      userHasAdmin,
      adminDocEnabled,
    });
    return { uid, isAdmin: true, source: 'token', debug };
  }

  if (userHasAdmin) {
    adminAuthProbe('resolveAdminAccess:granted', req, {
      authSource: authContext.source,
      source: 'users',
      userHasAdmin,
      adminDocEnabled,
    });
    return { uid, isAdmin: true, source: 'users', debug };
  }

  adminAuthProbe('resolveAdminAccess:resolved', req, {
    authSource: authContext.source,
    source: adminDocEnabled ? 'admins' : null,
    isAdmin: adminDocEnabled,
    userHasAdmin,
    adminDocEnabled,
  });

  return {
    uid,
    isAdmin: adminDocEnabled,
    source: adminDocEnabled ? 'admins' : null,
    debug,
  };
}

async function assertIsAdmin(req) {
  const access = await resolveAdminAccess(req);
  if (!access.isAdmin) {
    adminAuthProbe('assertIsAdmin:denied', req, {
      source: access.source || null,
    });
    throw new HttpsError('permission-denied', 'Admin only.');
  }

  return access;
}

async function getAuthUsersCount() {
  let total = 0;
  let pageToken = undefined;
  do {
    const res = await admin.auth().listUsers(1000, pageToken);
    total += res.users.length;
    pageToken = res.pageToken;
  } while (pageToken);
  return total;
}

function isProUserData(data) {
  if (!data || typeof data !== 'object') return false;
  const accountType = String(data.accountType || '').trim().toLowerCase();
  if (accountType === 'pro') return true;
  if (data.isPro === true) return true;
  return false;
}

exports.onAuthUserCreated = functionsV1.region(PROJECT_REGION).auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const db = admin.firestore();

  await db.collection("users").doc(uid).set(
    {
      uid,
      email: user.email || null,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
});

// ✅ Tracking client (best-effort) : une connexion utilisateur.
exports.trackUserLogin = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 10,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Authentication required.');

    // Anti-abus: limite très légère (10/min)
    await rateLimitOrThrow({ uid, action: 'track_login', limit: 10, windowSec: 60 });

    // ✅ Récupération des métriques enrichies
    const {
      authMethod = 'unknown',
      platform = 'unknown',
      deviceType = 'unknown',
      isNewUser = false,
      timestamp = Date.now()
    } = req.data || {};

    const userRef = admin.firestore().collection('users').doc(uid);
    const userSnap = await userRef.get();
    const userData = userSnap.data() || {};
    const isPro = isProUserData(userData);

    const inc = admin.firestore.FieldValue.increment(1);
    const now = admin.firestore.FieldValue.serverTimestamp();

    // ✅ Stats globales enrichies
    const statsPatch = {
      totalLogins: inc,
      updatedAt: now,
    };
    if (isPro) statsPatch.proLogins = inc;
    if (isNewUser) statsPatch.totalRegistrations = inc;

    // ✅ Stats par méthode d'authentification
    if (authMethod) {
      statsPatch[`loginsByMethod.${authMethod}`] = inc;
    }
    
    // ✅ Stats par plateforme
    if (platform) {
      statsPatch[`loginsByPlatform.${platform}`] = inc;
    }

    // ✅ Historique de connexion dans le profil utilisateur
    const loginHistory = {
      timestamp: admin.firestore.Timestamp.fromMillis(timestamp),
      method: authMethod,
      platform,
      deviceType,
    };

    await Promise.all([
      USER_STATS_DOC.set(statsPatch, { merge: true }),
      userRef.set(
        {
          lastLoginAt: now,
          lastSeenAt: now,
          status: 'online',
          lastAuthMethod: authMethod,
          lastPlatform: platform,
          lastDeviceType: deviceType,
          // ✅ Garder historique des 10 dernières connexions
          loginHistory: admin.firestore.FieldValue.arrayUnion(loginHistory),
        },
        { merge: true }
      ),
    ]);

    // ✅ Limiter l'historique à 10 entrées (asynchrone, best-effort)
    userRef.get().then((snap) => {
      const data = snap.data();
      const history = data?.loginHistory || [];
      if (history.length > 10) {
        userRef.update({
          loginHistory: history.slice(-10),
        }).catch(() => {});
      }
    }).catch(() => {});

    return {
      ok: true,
      isPro,
      isNewUser,
      authMethod,
      platform,
    };
  }
);

// ✅ Admin: stats utilisateurs pour la tuile "Utilisateurs".
exports.adminGetUserStats = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 20,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    await assertIsAdmin(req);

    const statsSnap = await USER_STATS_DOC.get();
    const stats = statsSnap.data() || {};

    let totalAccounts = Number(stats.totalAccounts || 0);
    if (!Number.isFinite(totalAccounts) || totalAccounts <= 0) {
      // Fallback si jamais le trigger n'a pas encore rempli la stat.
      totalAccounts = await getAuthUsersCount();
      await USER_STATS_DOC.set(
        {
          totalAccounts,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    const onlineSinceMs = Date.now() - 5 * 60 * 1000;
    const threshold = admin.firestore.Timestamp.fromMillis(onlineSinceMs);
    const onlineCountSnap = await admin
      .firestore()
      .collection('users')
      .where('lastSeenAt', '>=', threshold)
      .count()
      .get();

    const onlineUsers = Number(onlineCountSnap.data().count || 0);
    const proLogins = Number(stats.proLogins || 0);
    const totalRegistrations = Number(stats.totalRegistrations || 0);

    // ✅ Stats par méthode et plateforme
    const loginsByMethod = stats.loginsByMethod || {};
    const loginsByPlatform = stats.loginsByPlatform || {};

    return {
      totalAccounts,
      onlineUsers,
      proLogins,
      totalRegistrations,
      loginsByMethod,
      loginsByPlatform,
      windowMinutes: 5,
    };
  }
);
// ✅ Admin: vérifier rapidement l'accès admin sans dépendre de Remote Config.
exports.adminGetAccessStatus = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 15,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    const access = await assertIsAdmin(req);
    return {
      ok: true,
      isAdmin: true,
      uid: req.auth?.uid || null,
      source: access.source || 'unknown',
      checkedAt: Date.now(),
    };
  }
);

exports.getMyAdminAccessStatus = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 15,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    adminAuthProbe('getMyAdminAccessStatus:call', req, {
      callable: 'getMyAdminAccessStatus',
    });
    try {
      const access = await resolveAdminAccess(req);
      const payload = {
        ok: true,
        isAdmin: access.isAdmin,
        uid: access.uid || null,
        source: access.source,
        debug: access.debug || null,
        checkedAt: Date.now(),
      };
      adminAuthProbe('getMyAdminAccessStatus:success', req, {
        responseIsAdmin: payload.isAdmin,
        responseSource: payload.source || null,
      });
      return payload;
    } catch (error) {
      console.error('[admin-auth-probe]', {
        label: 'getMyAdminAccessStatus:error',
        project: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || null,
        region: PROJECT_REGION,
        callable: 'getMyAdminAccessStatus',
        code: error?.code || null,
        message: error?.message || String(error),
      });
      throw error;
    }
  }
);

// ✅ Obtenir le statut de présence d'un ou plusieurs utilisateurs
exports.getUserPresenceStatus = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 10,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Not signed in');

    const { userIds } = req.data || {};
    if (!Array.isArray(userIds) || userIds.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'userIds array required');
    }

    if (userIds.length > 50) {
      throw new functions.https.HttpsError('invalid-argument', 'Max 50 users at once');
    }

    const db = admin.firestore();
    const now = Date.now();
    const onlineThreshold = now - 5 * 60 * 1000; // 5 min
    const awayThreshold = now - 15 * 60 * 1000; // 15 min

    const userStatuses = {};

    const userDocs = await Promise.all(
      userIds.map((id) => db.collection('users').doc(id).get())
    );

    for (let i = 0; i < userDocs.length; i++) {
      const doc = userDocs[i];
      const userId = userIds[i];

      if (!doc.exists) {
        userStatuses[userId] = { status: 'offline', lastSeen: null };
        continue;
      }

      const data = doc.data();
      const lastSeenAt = data.lastSeenAt?.toMillis() || 0;
      const explicitStatus = data.status || null;

      let status = 'offline';
      if (explicitStatus === 'online' && lastSeenAt >= onlineThreshold) {
        status = 'online';
      } else if (lastSeenAt >= awayThreshold) {
        status = 'away';
      }

      userStatuses[userId] = {
        status,
        lastSeen: lastSeenAt > 0 ? lastSeenAt : null,
        sessionDuration: data.lastSessionDuration || null,
      };
    }

    return { statuses: userStatuses };
  }
);

function asString(v, def = '') {
  if (typeof v === 'string') return v;
  return def;
}

async function loadAudioBufferFromStorage(storagePath) {
  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  const [buf] = await file.download();
  return buf;
}

function parseWavHeader(buf) {
  try {
    if (!Buffer.isBuffer(buf)) return { isWav: false, dataBytes: 0 };
    if (buf.length < 44) return { isWav: false, dataBytes: buf.length };

    // RIFF header
    if (buf.toString('ascii', 0, 4) !== 'RIFF') return { isWav: false, dataBytes: buf.length };
    if (buf.toString('ascii', 8, 12) !== 'WAVE') return { isWav: false, dataBytes: buf.length };

    // Walk chunks to find "fmt " and "data"
    let fmt = null;
    let dataBytes = null;
    let offset = 12;
    while (offset + 8 <= buf.length) {
      const chunkId = buf.toString('ascii', offset, offset + 4);
      const chunkSize = buf.readUInt32LE(offset + 4);
      const chunkDataStart = offset + 8;
      const next = chunkDataStart + chunkSize;

      if (chunkId === 'fmt ') {
        if (chunkDataStart + 16 > buf.length) break;
        const audioFormat = buf.readUInt16LE(chunkDataStart + 0);
        const numChannels = buf.readUInt16LE(chunkDataStart + 2);
        const sampleRate = buf.readUInt32LE(chunkDataStart + 4);
        const bitsPerSample = buf.readUInt16LE(chunkDataStart + 14);
        fmt = { audioFormat, numChannels, sampleRate, bitsPerSample };
      }

      if (chunkId === 'data') {
        dataBytes = chunkSize;
      }

      if (fmt && typeof dataBytes === 'number') break;

      // chunk sizes are padded to even
      offset = next + (chunkSize % 2);
    }

    return {
      isWav: true,
      ...(fmt || {}),
      dataBytes: typeof dataBytes === 'number' ? dataBytes : buf.length,
    };
  } catch (_) {
    return { isWav: false, dataBytes: Buffer.isBuffer(buf) ? buf.length : 0 };
  }
}

function canUseGoogleStt(audioInfo) {
  if (!audioInfo || !audioInfo.isWav) return true; // may be raw PCM or other; let Google try
  // Google STT here is configured for LINEAR16. Only safe if PCM (format 1) + 16-bit.
  if (audioInfo.audioFormat == null || audioInfo.bitsPerSample == null) return true;
  return audioInfo.audioFormat === 1 && audioInfo.bitsPerSample === 16;
}

async function providerGoogleSTT({ audioBuffer, languageCode, audioInfo }) {
  const speechClient = getSpeechClient();

  if (!canUseGoogleStt(audioInfo)) {
    return {
      text: '',
      googleConfidence: null,
      raw: { skipped: true, reason: 'unsupported_audio_for_google_stt', audioInfo },
    };
  }

  const sampleRateHertz =
    typeof audioInfo?.sampleRate === 'number' && audioInfo.sampleRate > 0
      ? audioInfo.sampleRate
      : 16000;
  const audioChannelCount =
    typeof audioInfo?.numChannels === 'number' && audioInfo.numChannels > 0
      ? audioInfo.numChannels
      : 1;

  const request = {
    config: {
      encoding: "LINEAR16",
      sampleRateHertz,
      audioChannelCount,
      languageCode,
      enableAutomaticPunctuation: true,
      // Modèle optimisé pour les énoncés courts (< 60 s) : nettement plus
      // rapide que le modèle par défaut sur la dictée d'annonce.
      model: "latest_short",
    },
    audio: { content: audioBuffer.toString("base64") },
  };

  const [response] = await speechClient.recognize(request);

  const alternatives = response?.results?.flatMap((r) => r.alternatives || []) || [];
  const best = alternatives[0] || {};
  const text = best.transcript || "";
  const confidence = typeof best.confidence === "number" ? best.confidence : null;

  return { text, googleConfidence: confidence, raw: response };
}

async function providerWhisper({ audioBuffer, languageCode, openai }) {
  const file = await toFile(audioBuffer, "audio.wav");
  const res = await openai.audio.transcriptions.create({
    file,
    model: "whisper-1",
    language: languageCode?.startsWith("fr") ? "fr" : undefined,
  });
  return { text: res?.text || "", raw: res };
}

async function providerHybrid({ audioBuffer, languageCode, openai, audioInfo }) {
  const g = await providerGoogleSTT({ audioBuffer, languageCode, audioInfo });

  const prompt = `
Tu es un assistant de transcription FR.
Nettoie la transcription (corrige fautes, supprime répétitions, garde le sens).
Ne rajoute aucune information.
Rends un texte fluide en 1 paragraphe.

TRANSCRIPTION BRUTE:
${g.text}
`.trim();

  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    temperature: 0.2,
    messages: [
      { role: "system", content: "Tu produis uniquement le texte nettoyé, sans guillemets." },
      { role: "user", content: prompt },
    ],
  });

  const cleaned = completion?.choices?.[0]?.message?.content?.trim() || g.text;

  return { text: cleaned, googleConfidence: g.googleConfidence, raw: { google: g.raw, openai: completion } };
}

function buildTryOrder(mode) {
  if (mode === "GOOGLE_ONLY") return ["GOOGLE_ONLY"];
  if (mode === "WHISPER_ONLY") return ["WHISPER_ONLY"];
  return ["HYBRID", "WHISPER_ONLY", "GOOGLE_ONLY"];
}

function redactStoragePath(p) {
  if (typeof p !== 'string' || !p) return null;
  if (p.length <= 18) return p;
  return `${p.slice(0, 8)}…${p.slice(-8)}`;
}

function isAllowedAudioContentType(ct) {
  if (ct == null) return false;
  const v = String(ct).toLowerCase();
  return (
    v === 'audio/wav' ||
    v === 'audio/x-wav' ||
    v === 'audio/wave' ||
    v === 'audio/vnd.wave' ||
    v === 'audio/webm' ||
    v === 'video/webm' ||
    v === 'audio/mp4' ||
    v === 'video/mp4' ||
    v === 'audio/x-m4a' ||
    v === 'audio/aac'
  );
}

async function runFfmpegToWav16kMono({ inputPath, outputPath }) {
  if (!ffmpegPath) {
    throw new Error('ffmpeg-static not available (ffmpegPath is null). Did you install ffmpeg-static in functions/?');
  }

  // WAV PCM16 (s16le), 16kHz, mono
  const args = [
    '-y',
    '-i',
    inputPath,
    '-ac',
    '1',
    '-ar',
    '16000',
    '-acodec',
    'pcm_s16le',
    outputPath,
  ];

  await new Promise((resolve, reject) => {
    const p = spawn(ffmpegPath, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let err = '';
    p.stderr.on('data', (d) => (err += d.toString()));
    p.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg failed code=${code}\n${err}`));
    });
  });
}

async function prepareUploadedAudioForOpenAi({ uid, storagePath, requestId }) {
  if (!storagePath || typeof storagePath !== 'string') {
    throw new HttpsError('invalid-argument', 'storagePath is required (Firebase Storage path).');
  }

  if (storagePath.includes('..') || storagePath.startsWith('/') || storagePath.includes('\\')) {
    throw new HttpsError('invalid-argument', 'Invalid storagePath.');
  }

  const expectedPrefix = `stt/${uid}_`;
  const expectedStreamingPrefix = `stt_streaming/${uid}/`;
  const isWavPath = storagePath.endsWith('.wav');
  const isWebmPath = storagePath.endsWith('.webm');
  const isAacPath = storagePath.endsWith('.aac');
  const isM4aPath = storagePath.endsWith('.m4a');
  const isMp4Path = storagePath.endsWith('.mp4');
  const ownsPath = storagePath.startsWith(expectedPrefix) || storagePath.startsWith(expectedStreamingPrefix);
  const validExt = isWavPath || isWebmPath || isAacPath || isM4aPath || isMp4Path;
  if (!ownsPath || !validExt) {
    throw new HttpsError('permission-denied', 'storagePath does not belong to authenticated user.');
  }

  const bucket = admin.storage().bucket();
  const file = bucket.file(storagePath);
  const storagePathRedacted = redactStoragePath(storagePath);

  let metadata;
  try {
    const [rawMetadata] = await file.getMetadata();
    metadata = rawMetadata || null;
  } catch (error) {
    console.warn('[prepareUploadedAudioForOpenAi] META', {
      requestId,
      storagePath: storagePathRedacted,
      err: error?.message || String(error),
    });
    throw new HttpsError('not-found', 'Audio file not found.');
  }

  const objectBytes = Number(metadata?.size || 0);
  const contentType = metadata?.contentType || null;
  if (!Number.isFinite(objectBytes) || objectBytes <= 0) {
    throw new HttpsError('failed-precondition', 'Audio file is empty.');
  }
  if (objectBytes > 20_000_000) {
    throw new HttpsError('failed-precondition', `Audio trop gros (${objectBytes} bytes).`);
  }
  if (!isAllowedAudioContentType(contentType)) {
    throw new HttpsError(
      'failed-precondition',
      `Type audio invalide (contentType=${contentType || 'null'}).`
    );
  }

  let audioBuffer = await loadAudioBufferFromStorage(storagePath);
  let audioInfo = parseWavHeader(audioBuffer);
  const shouldConvertToWav = !audioInfo?.isWav || audioInfo.audioFormat !== 1 || audioInfo.bitsPerSample !== 16;

  if (shouldConvertToWav) {
    const tmpDir = path.join(os.tmpdir(), 'presto_openai_audio');
    const ext = isWebmPath
      ? '.webm'
      : (isAacPath ? '.aac' : (isM4aPath ? '.m4a' : (isMp4Path ? '.mp4' : '.bin')));
    const inputPath = path.join(tmpDir, `in_${requestId}${ext}`);
    const outputPath = path.join(tmpDir, `out_${requestId}.wav`);

    try {
      await fs.mkdir(tmpDir, { recursive: true });
      await fs.writeFile(inputPath, audioBuffer);
      await runFfmpegToWav16kMono({ inputPath, outputPath });
      audioBuffer = await fs.readFile(outputPath);
      audioInfo = parseWavHeader(audioBuffer);
    } finally {
      await fs.unlink(inputPath).catch(() => {});
      await fs.unlink(outputPath).catch(() => {});
    }
  }

  if (!audioInfo?.isWav) {
    throw new HttpsError('failed-precondition', 'Audio invalide: WAV requis.');
  }
  if (audioInfo.audioFormat !== 1 || audioInfo.bitsPerSample !== 16) {
    throw new HttpsError(
      'failed-precondition',
      `Audio invalide: WAV PCM 16-bit requis (format=${audioInfo.audioFormat}, bps=${audioInfo.bitsPerSample}).`
    );
  }
  if (!audioInfo || audioInfo.dataBytes < 30_000) {
    throw new HttpsError(
      'failed-precondition',
      `Audio trop court/faible (dataBytes=${audioInfo?.dataBytes || 0}). Réessaie en parlant plus près du micro.`
    );
  }

  const durationSec = estimateDurationSec(audioInfo);
  if (typeof durationSec === 'number' && durationSec > 120) {
    throw new HttpsError('failed-precondition', `Audio trop long (~${durationSec.toFixed(1)}s). Max 120s.`);
  }

  return {
    file,
    audioBuffer,
    audioInfo,
    durationSec,
    storagePathRedacted,
  };
}

function buildAudioTranscriptionPayload({ text, provider, languageCode, storagePath, durationSeconds }) {
  return {
    text: text || '',
    provider,
    languageCode,
    storagePath,
    durationSeconds: typeof durationSeconds === 'number' ? Number(durationSeconds.toFixed(2)) : null,
    confidence: null,
  };
}

exports.openAiTranscribeListingAudio = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 120,
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request) => {
    const uid = assertAuthenticated(request);
    await rateLimitOrThrow({ uid, action: 'openai_transcribe_listing_audio', limit: 20, windowSec: 60 });

    const storagePath = String(request.data?.storagePath || '').trim();
    const languageCode = nullableTrimmedString(request.data?.languageCode) || 'fr-FR';
    const requestId = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
    const apiKey = OPENAI_API_KEY.value();

    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY manquante');
    }

    let prepared;
    try {
      prepared = await prepareUploadedAudioForOpenAi({ uid, storagePath, requestId });
      const openai = new OpenAI({ apiKey });
      const transcription = await withTimeout(
        providerWhisper({
          audioBuffer: prepared.audioBuffer,
          languageCode,
          openai,
        }),
        60_000,
        'openai_transcribe_listing_audio'
      );

      const text = preprocessTranscript(transcription?.text || '');
      return {
        transcription: buildAudioTranscriptionPayload({
          text,
          provider: 'whisper-1',
          languageCode,
          storagePath,
          durationSeconds: prepared.durationSec,
        }),
      };
    } catch (error) {
      console.error('[openAiTranscribeListingAudio] Error:', {
        code: error?.code || null,
        message: error?.message || String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', error?.message || 'openAiTranscribeListingAudio failed');
    } finally {
      if (prepared?.file) {
        await prepared.file.delete().catch(() => {});
      }
    }
  }
);

exports.openAiExtractListingFieldsFromAudio = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 120,
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request) => {
    const uid = assertAuthenticated(request);
    await rateLimitOrThrow({ uid, action: 'openai_extract_listing_fields_from_audio', limit: 10, windowSec: 60 });

    const storagePath = String(request.data?.storagePath || '').trim();
    const city = nullableTrimmedString(request.data?.city) || '';
    const category = nullableTrimmedString(request.data?.category) || '';
    const languageCode = nullableTrimmedString(request.data?.languageCode) || 'fr-FR';
    const requestId = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
    const apiKey = OPENAI_API_KEY.value();

    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY manquante');
    }

    let prepared;
    try {
      prepared = await prepareUploadedAudioForOpenAi({ uid, storagePath, requestId });
      const openai = new OpenAI({ apiKey });
      const transcription = await withTimeout(
        providerWhisper({
          audioBuffer: prepared.audioBuffer,
          languageCode,
          openai,
        }),
        60_000,
        'openai_extract_listing_fields_from_audio_transcription'
      );

      const text = preprocessTranscript(transcription?.text || '');
      const result = text
        ? await _internalExtractListingFieldsWithOpenAi({
            openai,
            input: text,
            city,
            category,
            languageCode,
          })
        : normalizeListingAiResult({}, { city, category });

      return {
        result,
        transcription: buildAudioTranscriptionPayload({
          text,
          provider: 'whisper-1',
          languageCode,
          storagePath,
          durationSeconds: prepared.durationSec,
        }),
      };
    } catch (error) {
      console.error('[openAiExtractListingFieldsFromAudio] Error:', {
        code: error?.code || null,
        message: error?.message || String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', error?.message || 'openAiExtractListingFieldsFromAudio failed');
    } finally {
      if (prepared?.file) {
        await prepared.file.delete().catch(() => {});
      }
    }
  }
);

function estimateDurationSec(audioInfo) {
  const dataBytes = typeof audioInfo?.dataBytes === 'number' ? audioInfo.dataBytes : null;
  if (dataBytes == null || dataBytes <= 0) return null;
  const sampleRate = typeof audioInfo?.sampleRate === 'number' && audioInfo.sampleRate > 0 ? audioInfo.sampleRate : 16000;
  const numChannels = typeof audioInfo?.numChannels === 'number' && audioInfo.numChannels > 0 ? audioInfo.numChannels : 1;
  const bitsPerSample = typeof audioInfo?.bitsPerSample === 'number' && audioInfo.bitsPerSample > 0 ? audioInfo.bitsPerSample : 16;
  const bytesPerSecond = sampleRate * numChannels * (bitsPerSample / 8);
  if (!(bytesPerSecond > 0)) return null;
  const sec = dataBytes / bytesPerSecond;
  return Number.isFinite(sec) ? sec : null;
}

async function withTimeout(promise, ms, label) {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error(`timeout:${label}`)), ms);
  });
  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId);
  }
}

// ✅ Callable: microIaProcessAudio (1 seul endpoint pour ta page)
exports.microIaProcessAudio = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 120,
    // Instance toujours chaude : élimine le cold start (~3–6 s) qui dominait
    // la latence du remplissage IA (objectif ≤ 5 s du stop au remplissage).
    minInstances: 1,
    // Plus de mémoire = plus de vCPU (Cloud Run alloue le CPU proportionnellement).
    // Accélère à la fois le cold start (chargement des modules lourds : ffmpeg,
    // @google-cloud/speech, openai) ET le traitement CPU-bound (conversion
    // ffmpeg m4a→wav, manipulation du buffer audio).
    memory: "1GiB",
    cpu: 1,
    secrets: [OPENAI_API_KEY], // ⚠️ garde EXACTEMENT ta constante existante
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    console.log("[microIaProcessAudio] version=2026-01-01-ffmpeg-webm-1");
    try {
      const requestId = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
      const { storagePath, audioBase64, audioContentType, languageCode, generateDraft: wantDraft, draftCity, draftCategory } = req.data || {};
      const hasInlineAudio = typeof audioBase64 === 'string' && audioBase64.length > 0;
      const clientAuthUid = String(req.data?.clientAuthUid || '').trim() || null;
      const clientAuthEmail = String(req.data?.clientAuthEmail || '').trim() || null;
      const clientAuthSource = String(req.data?.clientAuthSource || '').trim() || null;
      const clientDebugLabel = String(req.data?.clientDebugLabel || '').trim() || null;
      const clientRequestId = String(req.data?.clientRequestId || '').trim() || null;
      const clientTokenPresent = req.data?.clientTokenPresent === true;
      const clientAppCheckTokenPresent = req.data?.clientAppCheckTokenPresent === true;
      const appCheckAppId = req.app?.appId || req.app?.app_id || null;
      const rawStoragePath = typeof storagePath === 'string' ? storagePath : '';
      const earlyStoragePathRedacted = rawStoragePath ? redactStoragePath(rawStoragePath) : null;

      const uid = req.auth?.uid || null;
      const authTokenExp = req.auth?.token?.exp || null;
      const authTokenIat = req.auth?.token?.iat || null;

      console.log('[microIaProcessAudio] CALL', {
        requestId,
        clientRequestId,
        clientDebugLabel,
        authPresent: Boolean(req.auth),
        uid,
        authTokenExp,
        authTokenIat,
        authTokenAgeSec: authTokenIat ? Math.floor(Date.now() / 1000) - authTokenIat : null,
        appCheckPresent: Boolean(req.app),
        appCheckAppId,
        clientAuthUid,
        clientAuthEmail,
        clientAuthSource,
        clientTokenPresent,
        clientAppCheckTokenPresent,
        storagePath: earlyStoragePathRedacted,
        inlineAudio: hasInlineAudio,
      });

      if (!uid) {
        console.warn('[microIaProcessAudio] AUTH_MISSING', {
          requestId,
          clientRequestId,
          clientDebugLabel,
          authPresent: Boolean(req.auth),
          authRawKeys: req.auth ? Object.keys(req.auth) : [],
          appCheckPresent: Boolean(req.app),
          appCheckAppId,
          clientAuthUid,
          clientAuthEmail,
          clientAuthSource,
          clientTokenPresent,
          clientAppCheckTokenPresent,
          storagePath: earlyStoragePathRedacted,
          clientSaysUserSignedIn: Boolean(clientAuthUid),
        });
        throw new HttpsError(
          "unauthenticated",
          "Authentication missing in callable context. Sign in again and retry the dictation."
        );
      }

      if (!hasInlineAudio && (!storagePath || typeof storagePath !== "string")) {
        throw new HttpsError("invalid-argument", "storagePath or audioBase64 is required.");
      }

      // 🔒 Rate limiting
      const isStreamingChunk = !hasInlineAudio && storagePath.startsWith('stt_streaming/');
      await rateLimitOrThrow({ uid, action: 'micro_ia_process', limit: isStreamingChunk ? 40 : 10, windowSec: 60 });

      const storagePathRedacted = hasInlineAudio ? '(inline)' : redactStoragePath(storagePath);

      // Extension du conteneur source (sert à nommer le fichier temporaire ffmpeg).
      let sourceExt = '.bin';
      // Objet Storage à nettoyer après traitement (chemin Storage uniquement).
      let file = null;

      if (!hasInlineAudio) {
        // Empêche chemins bizarres / traversal
        if (storagePath.includes('..') || storagePath.startsWith('/') || storagePath.includes('\\')) {
          throw new HttpsError("invalid-argument", "Invalid storagePath.");
        }

        // Ownership strict: stt/${uid}_*.wav OU stt_streaming/${uid}/*_chunk.wav
        const expectedPrefix = `stt/${uid}_`;
        const expectedStreamingPrefix = `stt_streaming/${uid}/`;
        const isWavPath = storagePath.endsWith('.wav');
        const isWebmPath = storagePath.endsWith('.webm');
        const isAacPath = storagePath.endsWith('.aac');
        const isM4aPath = storagePath.endsWith('.m4a');
        const isMp4Path = storagePath.endsWith('.mp4');
        const ownsPath = storagePath.startsWith(expectedPrefix) || storagePath.startsWith(expectedStreamingPrefix);
        const validExt = isWavPath || isWebmPath || isAacPath || isM4aPath || isMp4Path;
        if (!ownsPath || !validExt) {
          throw new HttpsError("permission-denied", "storagePath does not belong to authenticated user.");
        }
        sourceExt = isWebmPath
          ? '.webm'
          : (isAacPath ? '.aac' : (isM4aPath ? '.m4a' : (isMp4Path ? '.mp4' : '.wav')));
      }

      const cfg = await getMicroIaConfig();
      const lang = languageCode || cfg.languageCode;

      // Mode ultra-rapide (PRO): latence minimale, timeouts courts.
      // Objectif: réponse très rapide, avec fallback limité uniquement si le 1er résultat est trop faible.
      const ultraFastEnabled = cfg.ultraFastEnabled === true;

      const maxBytes = 20_000_000; // 20MB hard limit
      const _tDownload = Date.now();
      let audioBuffer;
      let objectBytes;

      if (hasInlineAudio) {
        // ⚡ Chemin rapide : l'audio arrive directement dans le payload du
        // callable. Évite l'upload Storage côté client + getMetadata +
        // download ici (~1-2,5 s économisées sur le remplissage IA).
        const inlineContentType = String(audioContentType || '').trim().toLowerCase();
        if (!isAllowedAudioContentType(inlineContentType)) {
          throw new HttpsError(
            "failed-precondition",
            `Type audio invalide (contentType=${inlineContentType || 'null'}). Envoie un WAV (audio/wav) ou WEBM (audio/webm).`
          );
        }
        audioBuffer = Buffer.from(audioBase64, 'base64');
        objectBytes = audioBuffer.length;
        if (objectBytes <= 0) {
          throw new HttpsError("failed-precondition", "Audio file is empty.");
        }
        if (objectBytes > maxBytes) {
          throw new HttpsError("failed-precondition", `Audio trop gros (${objectBytes} bytes).`);
        }
        sourceExt = inlineContentType.includes('webm')
          ? '.webm'
          : (inlineContentType === 'audio/aac'
            ? '.aac'
            : (inlineContentType === 'audio/x-m4a'
              ? '.m4a'
              : (inlineContentType.includes('mp4') ? '.mp4' : '.wav')));
      } else {
        // Garde-fous via metadata Storage AVANT download (coûts + RAM)
        const bucket = admin.storage().bucket();
        file = bucket.file(storagePath);
        let meta;
        try {
          const [m] = await file.getMetadata();
          meta = m || null;
        } catch (e) {
          console.warn("[microIaProcessAudio] META", { requestId, storagePath: storagePathRedacted, err: e?.message || String(e) });
          throw new HttpsError("not-found", "Audio file not found.");
        }

        objectBytes = Number(meta?.size || 0);
        const contentType = meta?.contentType || null;
        if (!Number.isFinite(objectBytes) || objectBytes <= 0) {
          throw new HttpsError("failed-precondition", "Audio file is empty.");
        }
        if (objectBytes > maxBytes) {
          throw new HttpsError("failed-precondition", `Audio trop gros (${objectBytes} bytes).`);
        }

        if (!isAllowedAudioContentType(contentType)) {
          throw new HttpsError(
            "failed-precondition",
            `Type audio invalide (contentType=${contentType || 'null'}). Envoie un WAV (audio/wav) ou WEBM (audio/webm).`
          );
        }

        audioBuffer = await loadAudioBufferFromStorage(storagePath);
      }

      let audioInfo = parseWavHeader(audioBuffer);
      const downloadMs = Date.now() - _tDownload;

      // Si ce n'est pas un WAV PCM16 exploitable (ex: WEBM/OPUS), on convertit côté serveur.
      let ffmpegMs = 0;
      const shouldConvertToWav = !audioInfo?.isWav || audioInfo.audioFormat !== 1 || audioInfo.bitsPerSample !== 16;
      if (shouldConvertToWav) {
        const _tFfmpeg = Date.now();
        const tmpDir = path.join(os.tmpdir(), 'presto_microia');
        const ext = sourceExt;
        const inputPath = path.join(tmpDir, `in_${requestId}${ext}`);
        const outputPath = path.join(tmpDir, `out_${requestId}.wav`);

        try {
          await fs.mkdir(tmpDir, { recursive: true });
          await fs.writeFile(inputPath, audioBuffer);

          console.log('[microIaProcessAudio] FFMPEG_CONVERT', {
            requestId,
            from: ext,
            bytes: audioBuffer?.length || 0,
          });

          await runFfmpegToWav16kMono({ inputPath, outputPath });
          audioBuffer = await fs.readFile(outputPath);
          audioInfo = parseWavHeader(audioBuffer);
          ffmpegMs = Date.now() - _tFfmpeg;
        } finally {
          // Best-effort cleanup
          await fs.unlink(inputPath).catch(() => {});
          await fs.unlink(outputPath).catch(() => {});
        }
      }

      console.log("[microIaProcessAudio] AUDIO", {
        requestId,
        bytes: audioBuffer?.length || 0,
        isWav: audioInfo?.isWav,
        sampleRate: audioInfo?.sampleRate,
        bitsPerSample: audioInfo?.bitsPerSample,
      });

      // Hardening: on attend un WAV PCM 16-bit (cohérent avec l'app)
      if (!audioInfo?.isWav) {
        throw new HttpsError("failed-precondition", "Audio invalide: WAV requis.");
      }
      if (audioInfo.audioFormat !== 1 || audioInfo.bitsPerSample !== 16) {
        throw new HttpsError(
          "failed-precondition",
          `Audio invalide: WAV PCM 16-bit requis (format=${audioInfo.audioFormat}, bps=${audioInfo.bitsPerSample}).`
        );
      }

      // Garde-fou: audio trop petit = transcription forcément mauvaise
      const minBytes = 30_000; // ~1s+ de WAV 16k mono 16-bit
      if (!audioInfo || audioInfo.dataBytes < minBytes) {
        throw new HttpsError(
          "failed-precondition",
          `Audio trop court/faible (dataBytes=${audioInfo?.dataBytes || 0}). Réessaie en parlant plus près du micro.`
        );
      }

      const durationSec = estimateDurationSec(audioInfo);
      const maxDurationSec = 120; // cohérent avec timeoutSeconds=120
      if (typeof durationSec === 'number' && durationSec > maxDurationSec) {
        throw new HttpsError(
          "failed-precondition",
          `Audio trop long (~${durationSec.toFixed(1)}s). Max ${maxDurationSec}s.`
        );
      }

      const tryOrder = isStreamingChunk
        ? ["GOOGLE_ONLY"]
        : ultraFastEnabled
          ? ["GOOGLE_ONLY", "WHISPER_ONLY"]
          : buildTryOrder(cfg.mode);

      // En ultra-rapide, on accepte plus souvent le premier résultat pour éviter d'enchaîner des tentatives.
      // On garde tout de même un fallback si le score est extrêmement bas (ex: texte vide).
      const threshold = ultraFastEnabled ? 0.10 : cfg.qualityThreshold;
      const fallbackEnabled = ultraFastEnabled ? true : cfg.fallbackEnabled;

      const needsOpenAI = tryOrder.some((m) => m !== "GOOGLE_ONLY") || wantDraft;
      const openai = needsOpenAI ? getOpenAiClient() : null;

      let best = null;
      let lastErr = null;
      const _tStt = Date.now();

      for (let i = 0; i < tryOrder.length; i++) {
        const attemptMode = tryOrder[i];

        try {
          let out;
          if (attemptMode === "GOOGLE_ONLY") {
            out = await withTimeout(
              providerGoogleSTT({ audioBuffer, languageCode: lang, audioInfo }),
              ultraFastEnabled ? 12_000 : 25_000,
              'google_stt'
            );
          } else if (attemptMode === "WHISPER_ONLY") {
            if (!openai) throw new Error("OpenAI client not initialized");
            out = await withTimeout(
              providerWhisper({ audioBuffer, languageCode: lang, openai }),
              ultraFastEnabled ? 20_000 : 60_000,
              'whisper'
            );
          } else {
            if (!openai) throw new Error("OpenAI client not initialized");
            out = await withTimeout(
              providerHybrid({ audioBuffer, languageCode: lang, openai, audioInfo }),
              ultraFastEnabled ? 25_000 : 80_000,
              'hybrid'
            );
          }

          const quality = evaluateQuality({
            text: out.text,
            googleConfidence: out.googleConfidence,
            audioInfo,
          });

          console.log("[microIaProcessAudio] TRY", {
            requestId,
            attemptMode,
            score: quality.score,
            textLen: (out.text || '').length,
          });

          best = {
            modeUsed: attemptMode,
            text: out.text,
            quality,
            meta: { language: lang, audioInfo, ultraFastEnabled },
          };

          if (quality.score >= threshold) break;
          if (!fallbackEnabled) break;
        } catch (e) {
          lastErr = e;
          console.warn("[microIaProcessAudio] TRY_ERROR", {
            requestId,
            attemptMode,
            err: e?.message || String(e),
          });

          // Continue uniquement si fallback activé et qu'il reste des tentatives
          if (!fallbackEnabled) break;
        }
      }

      if (!best) {
        throw new HttpsError(
          "internal",
          `All STT providers failed (requestId=${requestId}): ${lastErr?.message || 'unknown'}`
        );
      }

      const sttMs = Date.now() - _tStt;
      let draftMs = 0;

      console.log("[microIaProcessAudio] DONE", {
        modeUsed: best?.modeUsed,
        score: best?.quality?.score,
      });

      // ⚡ Mode combiné: STT + Draft en un seul round-trip (objectif <4s)
      if (wantDraft && best.text && best.text.trim().length > 0) {
        const _tDraft = Date.now();
        try {
          const draftOpenai = openai || getOpenAiClient();
          const draftResult = await withTimeout(
            _internalGenerateDraft({
              openai: draftOpenai,
              hint: preprocessTranscript(best.text),
              city: draftCity || '',
              category: draftCategory || '',
              lang: lang?.startsWith('fr') ? 'fr' : (lang || 'fr'),
              model: cfg.draftModel,
            }),
            15_000,
            'generate_draft'
          );
          best.draft = draftResult;
          draftMs = Date.now() - _tDraft;
        } catch (draftErr) {
          console.warn("[microIaProcessAudio] DRAFT_ERROR", {
            requestId,
            err: draftErr?.message || String(draftErr),
          });
          // Draft failure is non-fatal: client can still use the transcript
          best.draft = null;
          best.draftError = draftErr?.message || 'Draft generation failed';
        }
      }

      // 🧹 Cleanup hors chemin chaud: suppression fire-and-forget du fichier
      // audio source (chemin Storage uniquement — le chemin inline n'écrit rien).
      if (file) {
        file.delete().then(
          () => console.log("[microIaProcessAudio] CLEANUP", { requestId, storagePath: storagePathRedacted }),
          (cleanupErr) => console.warn("[microIaProcessAudio] CLEANUP_ERROR", {
            requestId,
            storagePath: storagePathRedacted,
            err: cleanupErr?.message || String(cleanupErr),
          }),
        );
      }

      // 📊 Décomposition des durées par étape (diagnostic latence pipeline).
      const totalMs = downloadMs + ffmpegMs + sttMs + draftMs;
      best.timings = { downloadMs, ffmpegMs, sttMs, draftMs, totalMs };
      console.log("[microIaProcessAudio] TIMINGS", {
        requestId,
        downloadMs,
        ffmpegMs,
        sttMs,
        draftMs,
        totalMs,
        modeUsed: best?.modeUsed,
        audioBytes: objectBytes,
      });

      return best;
    } catch (error) {
      console.error("[microIaProcessAudio] Error:", {
        code: error?.code || null,
        message: error?.message || String(error),
        authPresent: Boolean(req?.auth),
        uid: req?.auth?.uid || null,
        appCheckPresent: Boolean(req?.app),
        appCheckAppId: req?.app?.appId || req?.app?.app_id || null,
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "microIaProcessAudio failed");
    }
  }
);

// ✅ Admin: lire la config Micro-IA effective (Remote Config)
exports.adminGetMicroIaConfig = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 30,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    await assertIsAdmin(req);
    const cfg = await getMicroIaConfig({ forceRefresh: true });
    return cfg;
  }
);

// ✅ Admin: mettre à jour la config Micro-IA via Remote Config
exports.adminSetMicroIaConfig = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    await assertIsAdmin(req);

    const {
      mode,
      fallbackEnabled,
      qualityThreshold,
      languageCode,
    } = req.data || {};

    const nextMode = normalizeMode(mode);
    const nextFallback = asBool(fallbackEnabled, true);
    const nextThreshold = Math.max(0, Math.min(1, asNum(qualityThreshold, 0.62)));
    const nextLanguage = asString(languageCode, 'fr-FR') || 'fr-FR';
    const nextAudioQuality = normalizeAudioQuality(req.data?.audio_quality || req.data?.microia_audio_quality);

    const data = req.data || {};
    const hasUltraFast =
      Object.prototype.hasOwnProperty.call(data, 'ultraFastEnabled') ||
      Object.prototype.hasOwnProperty.call(data, 'microia_ultra_fast_enabled') ||
      Object.prototype.hasOwnProperty.call(data, 'microia_ultrafast_enabled') ||
      Object.prototype.hasOwnProperty.call(data, 'microia_ultra_fast');

    const tpl = await admin.remoteConfig().getTemplate();
    tpl.parameters = tpl.parameters || {};

    // Si l'appelant ne fournit pas le flag, on conserve la valeur existante.
    const currentUltraFast = normalizeUltraFastEnabled(
      tpl.parameters.microia_ultra_fast_enabled?.defaultValue?.value ||
        tpl.parameters.microia_ultrafast_enabled?.defaultValue?.value ||
        tpl.parameters.microia_ultra_fast?.defaultValue?.value ||
        false
    );
    const nextUltraFastEnabled = hasUltraFast
      ? normalizeUltraFastEnabled(
          data.ultraFastEnabled ?? data.microia_ultra_fast_enabled ?? data.microia_ultrafast_enabled ?? data.microia_ultra_fast
        )
      : currentUltraFast;

    tpl.parameters.microia_mode = tpl.parameters.microia_mode || {};
    tpl.parameters.microia_mode.defaultValue = { value: nextMode };

    tpl.parameters.microia_fallback_enabled = tpl.parameters.microia_fallback_enabled || {};
    tpl.parameters.microia_fallback_enabled.defaultValue = { value: nextFallback ? 'true' : 'false' };

    tpl.parameters.microia_quality_threshold = tpl.parameters.microia_quality_threshold || {};
    tpl.parameters.microia_quality_threshold.defaultValue = { value: String(nextThreshold) };

    tpl.parameters.microia_language_code = tpl.parameters.microia_language_code || {};
    tpl.parameters.microia_language_code.defaultValue = { value: nextLanguage };

    tpl.parameters.microia_audio_quality = tpl.parameters.microia_audio_quality || {};
    tpl.parameters.microia_audio_quality.defaultValue = { value: nextAudioQuality };

    tpl.parameters.microia_ultra_fast_enabled = tpl.parameters.microia_ultra_fast_enabled || {};
    tpl.parameters.microia_ultra_fast_enabled.defaultValue = { value: nextUltraFastEnabled ? 'true' : 'false' };

    await admin.remoteConfig().publishTemplate(tpl);

    // Invalider le cache local pour accélérer la prise en compte côté Functions.
    _microIaCfgCache = null;
    _microIaCfgCacheAt = 0;

    return {
      ok: true,
      mode: nextMode,
      fallbackEnabled: nextFallback,
      qualityThreshold: nextThreshold,
      languageCode: nextLanguage,
      audioQuality: nextAudioQuality,
      ultraFastEnabled: nextUltraFastEnabled,
    };
  }
);

// ============================================================================
// Photos d'offres: resize + filigrane UID (stockage optimisé)
// ============================================================================

exports.processOfferPhoto = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    const uid = assertAuthenticated(req);

    const storagePath = String(req.data?.storagePath || '').trim();
    if (!storagePath) {
      throw new HttpsError('invalid-argument', 'storagePath manquant');
    }

    // Doit provenir du dossier offers_raw/{uid}/...
    const expectedPrefix = `offers_raw/${uid}/`;
    if (!storagePath.startsWith(expectedPrefix)) {
      throw new HttpsError('permission-denied', 'Chemin non autorisé');
    }
    if (storagePath.includes('..') || storagePath.startsWith('/') || storagePath.includes('\\')) {
      throw new HttpsError('invalid-argument', 'Chemin invalide');
    }

    const bucket = admin.storage().bucket();
    const srcFile = bucket.file(storagePath);

    // Download
    let srcBuffer;
    try {
      const [buf] = await srcFile.download();
      srcBuffer = buf;
    } catch (e) {
      console.warn('[processOfferPhoto] download failed', e?.message || e);
      throw new HttpsError('not-found', 'Photo introuvable');
    }

    // Resize + watermark
    let out;
    try {
      const resized = await sharp(srcBuffer)
        .rotate()
        .resize({
          width: 1280,
          height: 1280,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 75 })
        .toBuffer({ resolveWithObject: true });

      const w = resized.info?.width || 1280;
      const h = resized.info?.height || 720;
      const fontSize = Math.max(14, Math.min(28, Math.round(w * 0.022)));
      const padX = Math.max(10, Math.round(w * 0.02));
      const padY = Math.max(10, Math.round(h * 0.02));

      const safeUid = uid.replace(/[<>&"']/g, '');
      const watermarkText = `UID ${safeUid}`;
      const svg = Buffer.from(
        `<svg width="${w}" height="${Math.max(44, fontSize + padY)}" xmlns="http://www.w3.org/2000/svg">
          <style>
            .t { font-family: Arial, sans-serif; font-size: ${fontSize}px; font-weight: 700; }
          </style>
          <rect x="0" y="0" width="${w}" height="${Math.max(44, fontSize + padY)}" fill="transparent"/>
          <text x="${padX}" y="${Math.max(32, fontSize + 12)}" class="t" fill="#000000" fill-opacity="0.55">${watermarkText}</text>
          <text x="${padX}" y="${Math.max(31, fontSize + 11)}" class="t" fill="#FFFFFF" fill-opacity="0.70">${watermarkText}</text>
        </svg>`
      );

      const withMark = await sharp(resized.data)
        .composite([
          {
            input: svg,
            gravity: 'southwest',
          },
        ])
        .webp({ quality: 75 })
        .toBuffer();

      out = withMark;
    } catch (e) {
      console.warn('[processOfferPhoto] sharp failed', e?.message || e);
      throw new HttpsError('internal', 'Traitement image impossible');
    }

    // Upload final
    const baseDestPath = storagePath
      .replace(/^offers_raw\//, 'offers/')
      .replace(/\.[^/.]+$/, '');
    const destPath = `${baseDestPath}.webp`;
    const token = randomUUID();

    try {
      await bucket.file(destPath).save(out, {
        contentType: 'image/webp',
        resumable: false,
        metadata: {
          cacheControl: 'public,max-age=31536000',
          metadata: {
            firebaseStorageDownloadTokens: token,
          },
        },
      });
    } catch (e) {
      console.warn('[processOfferPhoto] upload failed', e?.message || e);
      throw new HttpsError('internal', 'Upload image impossible');
    }

    // Cleanup raw (best-effort)
    try {
      await srcFile.delete();
    } catch (_) {
      // ignore
    }

    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destPath)}?alt=media&token=${token}`;
    return {
      ok: true,
      storagePath: destPath,
      downloadUrl,
    };
  }
);

// Les fonctions TypeScript compilées sont maintenant servies directement via
// lib/index.js (point d'entrée "main" dans package.json).
// Ce fichier ne contient plus que les callables legacy JS, importées par
// le bridge src/legacy/callables_compat.ts.

/**
 * Payment info MP3 pipeline.
 * Last export wins intentionally: this production implementation owns
 * generatePaymentInfoAudio.
 */
const paymentInfoAudioPipeline = require("./payment_info_audio_pipeline");
exports.generatePaymentInfoAudio = paymentInfoAudioPipeline.generatePaymentInfoAudio;
exports.generatePaymentInfoAudioDraft = paymentInfoAudioPipeline.generatePaymentInfoAudioDraft;
exports.publishPaymentInfoAudioDraft = paymentInfoAudioPipeline.publishPaymentInfoAudioDraft;

