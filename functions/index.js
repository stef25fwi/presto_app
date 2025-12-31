const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const OpenAI = require('openai');
const { createModerateNewOffer } = require('./moderation');

admin.initializeApp();

// Secrets (Firebase Functions v2)
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');

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

/**
 * Cloud Function qui génère un brouillon d'offre avec l'IA
 * 
 * Entrée : { hint, city, category, lang }
 * Sortie : { title, description, category, city, postalCode }
 */
exports.generateOfferDraft = onCall({ region: 'europe-west1', secrets: [OPENAI_API_KEY] }, async (request) => {
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

exports.transcribeAndDraftOffer = onCall({ region: 'europe-west1', timeoutSeconds: 120, secrets: [OPENAI_API_KEY] }, async (req) => {
  // Auth non obligatoire pour la transcription

  const {
    gcsUri,               // ex: "gs://bucket/stt/xxx.wav"
    languageCode = "fr-FR",
    category = "",
    city = "",
  } = req.data || {};

  if (!gcsUri) throw new HttpsError("invalid-argument", "gcsUri manquant.");

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

async function getMicroIaConfig() {
  const now = Date.now();
  if (_microIaCfgCache && (now - _microIaCfgCacheAt) < MICROIA_RC_CACHE_MS) {
    return _microIaCfgCache;
  }

  try {
    const tpl = await admin.remoteConfig().getTemplate();
    const p = tpl.parameters || {};

    const mode = normalizeMode(p.microia_mode?.defaultValue?.value || "HYBRID");
    const fallbackEnabled = asBool(p.microia_fallback_enabled?.defaultValue?.value, true);
    const qualityThreshold = asNum(p.microia_quality_threshold?.defaultValue?.value, 0.62);
    const languageCode = p.microia_language_code?.defaultValue?.value || "fr-FR";

    _microIaCfgCache = { mode, fallbackEnabled, qualityThreshold, languageCode };
    _microIaCfgCacheAt = now;
    return _microIaCfgCache;
  } catch (e) {
    console.warn("[getMicroIaConfig] Remote Config fetch failed, using defaults:", e?.message || e);
    _microIaCfgCache = { mode: "HYBRID", fallbackEnabled: true, qualityThreshold: 0.62, languageCode: "fr-FR" };
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
    if (googleConfidence >= 0.75) score += 0.25;
    else if (googleConfidence >= 0.60) score += 0.15;
    else reasons.push("low_confidence");
  } else {
    score += 0.10;
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

// ✅ Callable: microIaProcessAudio (1 seul endpoint pour ta page)
exports.microIaProcessAudio = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 120,
    secrets: [OPENAI_API_KEY], // ⚠️ garde EXACTEMENT ta constante existante
  },
  async (req) => {
    try {
      const { storagePath, languageCode } = req.data || {};
      if (!storagePath || typeof storagePath !== "string") {
        throw new HttpsError("invalid-argument", "storagePath is required (Firebase Storage path).");
      }

      const cfg = await getMicroIaConfig();
      const lang = languageCode || cfg.languageCode;

      const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

      const audioBuffer = await loadAudioBufferFromStorage(storagePath);
      const audioInfo = parseWavHeader(audioBuffer);

      // Garde-fou: audio trop petit = transcription forcément mauvaise
      const minBytes = 30_000; // ~1s+ de WAV 16k mono 16-bit
      if (!audioInfo || audioInfo.dataBytes < minBytes) {
        throw new HttpsError(
          "failed-precondition",
          `Audio trop court/faible (dataBytes=${audioInfo?.dataBytes || 0}). Réessaie en parlant plus près du micro.`
        );
      }

      const tryOrder = buildTryOrder(cfg.mode);
      const threshold = cfg.qualityThreshold;
      const fallbackEnabled = cfg.fallbackEnabled;

      let best = null;

      for (let i = 0; i < tryOrder.length; i++) {
        const attemptMode = tryOrder[i];

        let out;
        if (attemptMode === "GOOGLE_ONLY") {
          out = await providerGoogleSTT({ audioBuffer, languageCode: lang, audioInfo });
        } else if (attemptMode === "WHISPER_ONLY") {
          out = await providerWhisper({ audioBuffer, languageCode: lang, openai });
        } else {
          out = await providerHybrid({ audioBuffer, languageCode: lang, openai, audioInfo });
        }

        const quality = evaluateQuality({
          text: out.text,
          googleConfidence: out.googleConfidence,
          audioInfo,
        });

        best = {
          modeUsed: attemptMode,
          text: out.text,
          quality,
          meta: { language: lang, audioInfo },
        };

        if (quality.score >= threshold) break;
        if (!fallbackEnabled) break;
      }

      return best;
    } catch (error) {
      console.error("[microIaProcessAudio] Error:", error);
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
  },
  async (req) => {
    await assertIsAdmin(req);
    const cfg = await getMicroIaConfig();
    return cfg;
  }
);

// ✅ Admin: mettre à jour la config Micro-IA via Remote Config
exports.adminSetMicroIaConfig = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 60,
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

    const tpl = await admin.remoteConfig().getTemplate();
    tpl.parameters = tpl.parameters || {};

    tpl.parameters.microia_mode = tpl.parameters.microia_mode || {};
    tpl.parameters.microia_mode.defaultValue = { value: nextMode };

    tpl.parameters.microia_fallback_enabled = tpl.parameters.microia_fallback_enabled || {};
    tpl.parameters.microia_fallback_enabled.defaultValue = { value: nextFallback ? 'true' : 'false' };

    tpl.parameters.microia_quality_threshold = tpl.parameters.microia_quality_threshold || {};
    tpl.parameters.microia_quality_threshold.defaultValue = { value: String(nextThreshold) };

    tpl.parameters.microia_language_code = tpl.parameters.microia_language_code || {};
    tpl.parameters.microia_language_code.defaultValue = { value: nextLanguage };

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
    };
  }
);
