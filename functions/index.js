const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const functionsV1 = require("firebase-functions/v1");
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
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

const ENFORCE_APP_CHECK = String(process.env.ENFORCE_APP_CHECK || '').toLowerCase() === 'true';

const USER_STATS_DOC = admin.firestore().collection('_stats').doc('users');

// Secrets (Firebase Functions v2)
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
const GOOGLE_PLACES_API_KEY = defineSecret('GOOGLE_PLACES_API_KEY');

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
 * de reconnaissance vocale française
 */
function preprocessTranscript(text) {
  if (!text) return '';
  
  let cleaned = text.toLowerCase().trim();
  
  // Corrections communes pour les villes des Antilles
  const cityCorrections = {
    'baie ma haut': 'baie-mahault',
    'baie mahaut': 'baie-mahault',
    'bye mahaut': 'baie-mahault',
    'les zabîmes': 'les abymes',
    'les abîmes': 'les abymes',
    'pointe à pitre': 'pointe-à-pitre',
    'fort de france': 'fort-de-france',
    'le lamentin': 'le lamentin',
    'petit bourg': 'petit-bourg',
    'le gosier': 'le gosier',
    'sainte anne': 'sainte-anne',
    'saint françois': 'saint-françois',
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
    region: 'europe-west1',
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
      predictions: predictions.slice(0, 10).map((p) => ({
        description: String(p?.description || ''),
        placeId: String(p?.place_id || ''),
      })),
    };
  }
);

exports.placesDetails = onCall(
  {
    region: 'europe-west1',
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

/**
 * Cloud Function qui génère un brouillon d'offre avec l'IA
 * 
 * Entrée : { hint, city, category, lang }
 * Sortie : { title, description, category, city, postalCode }
 */
exports.generateOfferDraft = onCall({ region: 'europe-west1', secrets: [OPENAI_API_KEY], enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  // 🔒 Auth requise (y compris auth anonyme côté app)
  assertAuthenticated(request);

  let { hint, city, category, lang = 'fr' } = request.data;

  // Prétraiter le texte transcrit
  const originalHint = hint;
  hint = preprocessTranscript(hint);
  
  if (originalHint !== hint) {
    console.log('[generateOfferDraft] Texte prétraité:', { original: originalHint, cleaned: hint });
  }

  // Validation basique
  if (!hint || typeof hint !== 'string' || hint.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Le paramètre "hint" est requis');
  }

  // Initialiser OpenAI ici avec la clé d'environnement
  const apiKey = OPENAI_API_KEY.value();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'OPENAI_API_KEY manquante (configure la secret avec firebase functions:secrets:set OPENAI_API_KEY)');
  }
  const openai = new OpenAI({ apiKey });
  console.log('[generateOfferDraft] start', {
    hintLength: hint.length,
    city: city || '',
    category: category || '',
    lang,
  });

  try {
    // Prompt système recommandé avec format JSON riche
    const systemPrompt = `Tu es un assistant rédactionnel pour l'application Prestō.
Objectif : transformer une transcription vocale brute en une annonce claire, courte et attractive.

Règles :
- N'invente jamais d'informations (prix, lieu, date, identité, etc.). Si manquant : mets null + ajoute une question dans "questions_a_poser".
- Français naturel (Guadeloupe/France OK), style simple et professionnel.
- Corrige les fautes, enlève les hésitations ("euh", répétitions), restructure en phrases.
- Si le besoin est ambigu, propose 2 formulations de titre dans "suggestions_titres".
- Respecte STRICTEMENT le format JSON demandé. Aucun texte hors JSON.

FORMAT JSON (obligatoire) :
{
  "titre": string,
  "suggestions_titres": [string, string],
  "categorie": string|null,
  "ville": string|null,
  "secteur": string|null,
  "budget": {
    "type": "fixe"|"horaire"|null,
    "min": number|null,
    "max": number|null,
    "devise": "EUR"
  },
  "urgence": "immediat"|"24h"|"7j"|"flexible"|null,
  "description_courte": string,
  "details": [string],
  "competences_requises": [string],
  "materiel": {
    "fourni_par_demandeur": [string],
    "a_prevoir_par_prestataire": [string]
  },
  "disponibilites": string|null,
  "questions_a_poser": [string]
}`;

    const userPrompt = `Voici la transcription brute de l'utilisateur (peut contenir des erreurs) :
${hint}

Contexte (si dispo) :
- Ville détectée (si dispo) : ${city || 'Non détectée'}
- Catégorie choisie (si dispo) : ${category || 'Non spécifiée'}
- Langue : ${lang}

Génère l'annonce.`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.4,
      max_tokens: 600
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
      // Fallback minimal si le JSON est invalide - format riche
      console.warn('[generateOfferDraft] Parsing JSON échoué, utilisation fallback:', e.message);
      draft = {
        titre: 'Nouvelle demande',
        suggestions_titres: [],
        description_courte: `Je recherche: ${hint}`,
        categorie: category || null,
        ville: city || null,
        secteur: null,
        budget: { type: null, min: null, max: null, devise: 'EUR' },
        urgence: null,
        details: [],
        competences_requises: [],
        materiel: { fourni_par_demandeur: [], a_prevoir_par_prestataire: [] },
        disponibilites: null,
        questions_a_poser: []
      };
    }

    // Validation du format (titre obligatoire)
    if (!draft.titre && !draft.title) {
      throw new Error('Réponse IA invalide : titre manquant');
    }

    console.log('[generateOfferDraft] success', {
      titre: draft.titre || draft.title || '',
      categorie: draft.categorie || category || null,
      ville: draft.ville || city || null,
      hasQuestions: (draft.questions_a_poser || []).length
    });

    // Déduire le code postal à partir de la ville si non fourni par l'IA
    const finalCity = draft.ville || city || '';
    let finalPostalCode = '';
    
    if (finalCity && !draft.postalCode) {
      finalPostalCode = findPostalCode(finalCity);
      console.log('[generateOfferDraft] Code postal déduit:', { city: finalCity, postalCode: finalPostalCode });
    } else {
      finalPostalCode = draft.postalCode || '';
    }

    // Retourne le brouillon enrichi (nouveau format)
    return {
      // Compatibilité avec ancien format
      title: draft.titre || draft.title || '',
      description: draft.description_courte || draft.description || '',
      category: draft.categorie || category || 'Autre',
      city: finalCity,
      postalCode: finalPostalCode,
      
      // Nouveau format riche
      titre: draft.titre || draft.title || '',
      suggestions_titres: draft.suggestions_titres || [],
      description_courte: draft.description_courte || draft.description || '',
      categorie: draft.categorie || category || null,
      ville: finalCity,
      secteur: draft.secteur || null,
      budget: draft.budget || { type: null, min: null, max: null, devise: 'EUR' },
      urgence: draft.urgence || null,
      details: draft.details || [],
      competences_requises: draft.competences_requises || [],
      materiel: draft.materiel || { fourni_par_demandeur: [], a_prevoir_par_prestataire: [] },
      disponibilites: draft.disponibilites || null,
      questions_a_poser: draft.questions_a_poser || []
    };

  } catch (error) {
    console.error('Erreur generateOfferDraft:', error);
    
    if (error.message?.includes('JSON')) {
      throw new HttpsError('internal', 'Erreur de parsing de la réponse IA');
    }
    
    throw new HttpsError('internal', `Erreur IA : ${error.message}`);
  }
});

// ============================================================================
// Fonction de transcription audio + rédaction avec OpenAI
// ============================================================================

exports.transcribeAndDraftOffer = onCall({ region: 'europe-west1', timeoutSeconds: 120, secrets: [OPENAI_API_KEY], enforceAppCheck: ENFORCE_APP_CHECK }, async (req) => {
  // 🔒 Auth requise (y compris auth anonyme côté app)
  const uid = assertAuthenticated(req);

  const {
    gcsUri,               // ex: "gs://bucket/stt/xxx.wav"
    languageCode = "fr-FR",
    category = "",
    city = "",
  } = req.data || {};

  if (!gcsUri) throw new HttpsError("invalid-argument", "gcsUri manquant.");

  // 🔒 Validation stricte de l'URI + ownership
  const parsed = parseGsUri(gcsUri);
  if (!parsed) throw new HttpsError('invalid-argument', 'gcsUri invalide (format gs://bucket/object requis).');

  // Bucket doit être le bucket Firebase du projet
  const defaultBucket = admin.storage().bucket();
  const defaultBucketName = defaultBucket?.name;
  if (defaultBucketName && parsed.bucket !== defaultBucketName) {
    throw new HttpsError('permission-denied', 'gcsUri bucket non autorisé.');
  }

  // Doit provenir du dossier stt/ et appartenir à l'utilisateur
  const expectedPrefix = `stt/${uid}_`;
  const objectPath = parsed.object;
  const isWav = objectPath.endsWith('.wav');
  if (!objectPath.startsWith(expectedPrefix) || !isWav) {
    throw new HttpsError('permission-denied', 'gcsUri non autorisé (stt/${uid}_*.wav requis).');
  }

  // Garde-fous taille + durée (approx) via metadata Storage
  const file = defaultBucket.file(objectPath);
  let meta;
  try {
    const [m] = await file.getMetadata();
    meta = m || null;
  } catch (_) {
    throw new HttpsError('not-found', 'Fichier audio introuvable.');
  }

  const objectBytes = Number(meta?.size || 0);
  const maxBytes = 20_000_000; // 20MB
  if (!Number.isFinite(objectBytes) || objectBytes <= 0) {
    throw new HttpsError('failed-precondition', 'Audio vide.');
  }
  if (objectBytes > maxBytes) {
    throw new HttpsError('failed-precondition', `Audio trop gros (${objectBytes} bytes).`);
  }

  const ct = String(meta?.contentType || '').toLowerCase();
  if (ct && !isAllowedAudioContentType(ct)) {
    throw new HttpsError('failed-precondition', `Type audio invalide (contentType=${ct}).`);
  }

  // Approx: WAV PCM16 16kHz mono ≈ 32000 bytes/sec. On accepte un peu de marge.
  const approxBytesPerSec = 32_000;
  const approxDurationSec = objectBytes / approxBytesPerSec;
  const maxDurationSec = 120;
  if (Number.isFinite(approxDurationSec) && approxDurationSec > (maxDurationSec + 10)) {
    throw new HttpsError('failed-precondition', `Audio trop long (~${approxDurationSec.toFixed(1)}s). Max ${maxDurationSec}s.`);
  }

  // Anti-abus: limite d'appels par utilisateur
  await rateLimitOrThrow({ uid, action: 'transcribe_and_draft', limit: 10, windowSec: 60 });

  try {
    // 1) Transcription : utiliser l'API Speech-to-Text v1
    const speech = require("@google-cloud/speech");
    const speechClient = new speech.SpeechClient();

    console.log("[STT] Starting transcription for:", gcsUri);

    const request = {
      audio: { uri: gcsUri },
      config: {
        encoding: "LINEAR16",
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
      },
    };

    const [response] = await speechClient.recognize(request);
    let transcript = (response.results || [])
      .map(r => (r.alternatives?.[0]?.transcript || ""))
      .join("\n")
      .trim();

    // Corrections simples (accents/villes)
    transcript = preprocessTranscript(transcript);

    console.log("[STT] Transcript received:", transcript.substring(0, 100));

    if (!transcript) {
      throw new HttpsError("failed-precondition", "Transcription vide (audio trop court/bruité ?).");
    }

    // 2) Rédaction IA avec OpenAI (plus fiable que Vertex AI)
    const apiKey2 = OPENAI_API_KEY.value();
    if (!apiKey2) {
      throw new HttpsError('failed-precondition', 'OPENAI_API_KEY manquante');
    }
    const openai = new OpenAI({ apiKey: apiKey2 });

    console.log("[AI] Calling OpenAI for draft generation...");

    const systemPrompt = `Tu es un assistant de rédaction d'annonces pour une app de services.
À partir d'une transcription brute, génère un JSON STRICT (pas de markdown) :

{
  "title": "…",
  "description": "…",
  "category": "…",
  "city": "…",
  "postalCode": "…"
}

Règles :
- Titre court (max 60 caractères)
- Description pro (150-300 mots)
- Ne pas inventer de prix, téléphone, infos perso
- Garder le français
- Catégorie fournie: ${category}
- Ville fournie: ${city}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Transcription : ${transcript}` }
      ],
      temperature: 0.7,
      max_tokens: 800
    });

    const aiResponse = completion.choices[0]?.message?.content?.trim();
    console.log("[AI] OpenAI response received");

    if (!aiResponse) {
      throw new Error('Pas de réponse de OpenAI');
    }

    // Parse le JSON
    let draft;
    try {
      let cleanedText = aiResponse;
      if (cleanedText.startsWith('```json')) {
        cleanedText = cleanedText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
      } else if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.replace(/^```\s*/, '').replace(/\s*```$/, '');
      }
      draft = JSON.parse(cleanedText);
    } catch (e) {
      console.error("[AI] JSON parse error:", e.message);
      // Fallback
      draft = {
        title: "Nouvelle offre",
        description: transcript,
        category: category || "Autre",
        city: city || "",
        postalCode: ""
      };
    }

    // Déduire ville & code postal si manquant
    const finalCity = (draft.city || city || '').trim();
    let finalPostalCode = (draft.postalCode || '').trim();
    if (finalCity && !finalPostalCode) {
      finalPostalCode = findPostalCode(finalCity);
    }

    console.log("[DONE] Returning flattened draft");
    return {
      transcript,
      title: draft.title || '',
      description: draft.description || transcript,
      category: draft.category || category || 'Autre',
      city: finalCity,
      postalCode: finalPostalCode,
    };

  } catch (error) {
    console.error('[transcribeAndDraftOffer] Error:', error);
    throw new HttpsError('internal', `Erreur transcription : ${error.message}`);
  }
});

// =====================================================
// Micro-IA Router: HYBRID / GOOGLE_ONLY / WHISPER_ONLY
// StoragePath in Firebase Storage: "stt/uid_timestamp.wav"
// =====================================================

const speech = require("@google-cloud/speech");
const { toFile } = require("openai");

exports.moderateNewOffer = createModerateNewOffer({
  admin,
  onDocumentCreated,
  region: 'europe-west1',
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

    const mode = normalizeMode(p.microia_mode?.defaultValue?.value || "HYBRID");
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

    _microIaCfgCache = { mode, fallbackEnabled, qualityThreshold, languageCode, audioQuality, ultraFastEnabled };
    _microIaCfgCacheAt = now;
    return _microIaCfgCache;
  } catch (e) {
    console.warn("[getMicroIaConfig] Remote Config fetch failed, using defaults:", e?.message || e);
    _microIaCfgCache = { mode: "HYBRID", fallbackEnabled: true, qualityThreshold: 0.62, languageCode: "fr-FR", audioQuality: 'MEDIUM', ultraFastEnabled: false };
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

async function assertIsAdmin(req) {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const snap = await admin.firestore().collection('admins').doc(uid).get();
  const data = snap.data() || {};
  const enabled = data.enabled !== false; // défaut: true si doc existe

  if (!snap.exists || !enabled) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }
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

exports.onAuthUserCreated = functionsV1.auth.user().onCreate(async (user) => {
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
    region: 'europe-west1',
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
    region: 'europe-west1',
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

// ✅ Obtenir le statut de présence d'un ou plusieurs utilisateurs
exports.getUserPresenceStatus = onCall(
  {
    region: 'europe-west1',
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
  const speechClient = new speech.SpeechClient();

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
    v === 'audio/aac' ||
    v === 'application/octet-stream'
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
    region: "europe-west1",
    timeoutSeconds: 120,
    secrets: [OPENAI_API_KEY], // ⚠️ garde EXACTEMENT ta constante existante
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (req) => {
    console.log("[microIaProcessAudio] version=2026-01-01-ffmpeg-webm-1");
    try {
      const requestId = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
      const { storagePath, languageCode } = req.data || {};

      console.log("[microIaProcessAudio] CALL", {
        uid: req.auth?.uid || null,
        storagePath,
        languageCode,
      });

      const uid = req.auth?.uid || null;
      const storagePathRedacted = redactStoragePath(storagePath);

      console.log("[microIaProcessAudio] CALL", {
        requestId,
        storagePath: storagePathRedacted,
        languageCode,
        uid,
      });

      if (!uid) {
        throw new HttpsError("unauthenticated", "Authentication required.");
      }

      if (!storagePath || typeof storagePath !== "string") {
        throw new HttpsError("invalid-argument", "storagePath is required (Firebase Storage path).");
      }

      // Empêche chemins bizarres / traversal
      if (storagePath.includes('..') || storagePath.startsWith('/') || storagePath.includes('\\')) {
        throw new HttpsError("invalid-argument", "Invalid storagePath.");
      }

      // Ownership strict: la page client upload sous stt/${uid}_${timestamp}.wav
      const expectedPrefix = `stt/${uid}_`;
      const isWavPath = storagePath.endsWith('.wav');
      const isWebmPath = storagePath.endsWith('.webm');
      const isM4aPath = storagePath.endsWith('.m4a');
      const isMp4Path = storagePath.endsWith('.mp4');
      if (!storagePath.startsWith(expectedPrefix) || (!isWavPath && !isWebmPath && !isM4aPath && !isMp4Path)) {
        throw new HttpsError("permission-denied", "storagePath does not belong to authenticated user.");
      }

      const cfg = await getMicroIaConfig();
      const lang = languageCode || cfg.languageCode;

      // Mode ultra-rapide (PRO): latence minimale, timeouts courts.
      // Objectif: réponse très rapide, avec fallback limité uniquement si le 1er résultat est trop faible.
      const ultraFastEnabled = cfg.ultraFastEnabled === true;

      // Garde-fous via metadata Storage AVANT download (coûts + RAM)
      const bucket = admin.storage().bucket();
      const file = bucket.file(storagePath);
      let meta;
      try {
        const [m] = await file.getMetadata();
        meta = m || null;
      } catch (e) {
        console.warn("[microIaProcessAudio] META", { requestId, storagePath: storagePathRedacted, err: e?.message || String(e) });
        throw new HttpsError("not-found", "Audio file not found.");
      }

      const objectBytes = Number(meta?.size || 0);
      const contentType = meta?.contentType || null;
      const maxBytes = 20_000_000; // 20MB hard limit
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

      let audioBuffer = await loadAudioBufferFromStorage(storagePath);
      let audioInfo = parseWavHeader(audioBuffer);

      // Si ce n'est pas un WAV PCM16 exploitable (ex: WEBM/OPUS), on convertit côté serveur.
      const shouldConvertToWav = !audioInfo?.isWav || audioInfo.audioFormat !== 1 || audioInfo.bitsPerSample !== 16;
      if (shouldConvertToWav) {
        const tmpDir = path.join(os.tmpdir(), 'presto_microia');
        const ext = isWebmPath ? '.webm' : (isM4aPath ? '.m4a' : (isMp4Path ? '.mp4' : '.bin'));
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
        } finally {
          // Best-effort cleanup
          await fs.unlink(inputPath).catch(() => {});
          await fs.unlink(outputPath).catch(() => {});
        }
      }

      console.log("[microIaProcessAudio] AUDIO", {
        isWav: audioInfo?.isWav,
        sampleRate: audioInfo?.sampleRate,
        numChannels: audioInfo?.numChannels,
        bitsPerSample: audioInfo?.bitsPerSample,
        dataBytes: audioInfo?.dataBytes,
      });
      console.log("[microIaProcessAudio] audioInfo=", audioInfo, "bufBytes=", audioBuffer?.length);

      if (audioBuffer?.length && objectBytes && audioBuffer.length !== objectBytes) {
        console.warn("[microIaProcessAudio] SIZE_MISMATCH", {
          requestId,
          storagePath: storagePathRedacted,
          metaBytes: objectBytes,
          downloadedBytes: audioBuffer.length,
        });
      }

      console.log("[microIaProcessAudio] AUDIO", {
        requestId,
        bytes: audioBuffer?.length || 0,
        audioInfo,
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

      const tryOrder = ultraFastEnabled
        ? ["GOOGLE_ONLY", "WHISPER_ONLY"]
        : buildTryOrder(cfg.mode);

      // En ultra-rapide, on accepte plus souvent le premier résultat pour éviter d'enchaîner des tentatives.
      // On garde tout de même un fallback si le score est extrêmement bas (ex: texte vide).
      const threshold = ultraFastEnabled ? 0.10 : cfg.qualityThreshold;
      const fallbackEnabled = ultraFastEnabled ? true : cfg.fallbackEnabled;

      const needsOpenAI = tryOrder.some((m) => m !== "GOOGLE_ONLY");
      const openai = needsOpenAI ? new OpenAI({ apiKey: OPENAI_API_KEY.value() }) : null;

      let best = null;
      let lastErr = null;

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
            attemptMode,
            score: quality?.score,
            reasons: quality?.reasons,
          });

          console.log("[microIaProcessAudio] TRY", {
            requestId,
            attemptMode,
            score: quality.score,
            reasons: quality.reasons,
            googleConfidence: out.googleConfidence ?? null,
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

      console.log(
        "[microIaProcessAudio] modeUsed=",
        best?.modeUsed,
        "score=",
        best?.quality?.score,
        "reasons=",
        best?.quality?.reasons
      );

      console.log("[microIaProcessAudio] DONE", {
        modeUsed: best?.modeUsed,
        score: best?.quality?.score,
      });

      return best;
    } catch (error) {
      console.error("[microIaProcessAudio] Error:", {
        code: error?.code || null,
        message: error?.message || String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "microIaProcessAudio failed");
    }
  }
);

// ✅ Admin: lire la config Micro-IA effective (Remote Config)
exports.adminGetMicroIaConfig = onCall(
  {
    region: 'europe-west1',
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
    region: 'europe-west1',
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
    region: 'europe-west1',
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
        .jpeg({ quality: 75, mozjpeg: true })
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
        .jpeg({ quality: 75, mozjpeg: true })
        .toBuffer();

      out = withMark;
    } catch (e) {
      console.warn('[processOfferPhoto] sharp failed', e?.message || e);
      throw new HttpsError('internal', 'Traitement image impossible');
    }

    // Upload final
    const destPath = storagePath.replace(/^offers_raw\//, 'offers/');
    const token = randomUUID();

    try {
      await bucket.file(destPath).save(out, {
        contentType: 'image/jpeg',
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
