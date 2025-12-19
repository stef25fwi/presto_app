const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const OpenAI = require('openai');

initializeApp();

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
    // Prompt pour l'IA (style demande "Je recherche…")
    const systemPrompt = `Tu écris des DEMANDES de services courtes pour des particuliers en Guadeloupe et en Martinique.
Ton objectif : produire un JSON STRICT (sans markdown) avec un titre et une description courte (1–2 phrases) commençant par "Je recherche…". 
La description doit mentionner clairement le métier, la tâche et le secteur/ville. Ajoute éventuellement l'urgence et/ou un budget si ces éléments sont présents dans l'indice.

IMPORTANT : Le texte peut contenir des erreurs de transcription vocale (reconnaissance vocale). Interprète intelligemment le sens général, corrige les fautes et déduis l'intention réelle.
Exemples :
- "jardinier baie mahault" ou "jardinage à baie ma haut" → Ville: "Baie-Mahault"
- "serveur fort de France" → Ville: "Fort-de-France", Catégorie: "Restauration / Extra"
- "je cherche quelqu'un pour tondre mon jardin à petit bourg" → Ville: "Petit-Bourg", Catégorie: "Jardinage"

Contraintes et champs :
- Titre : court, accrocheur, max 60 caractères.
- Description : 1–2 phrases, commence par "Je recherche…".
- Catégories autorisées : Jardinage, Bricolage, Ménage, Restauration / Extra, DJ / Sono, Baby-sitting, Transport / Livraison, Informatique, Autre.
- Ville : déduis du texte en corrigeant les erreurs de transcription. Liste des villes principales : Baie-Mahault, Les Abymes, Pointe-à-Pitre, Le Gosier, Petit-Bourg, Fort-de-France, Le Lamentin, Schoelcher, etc.
- Code postal : si connu dans le texte, sinon vide (sera déduit automatiquement).

Réponds UNIQUEMENT avec un objet JSON valide :
{
  "title": "…",
  "description": "Je recherche …",
  "category": "…",
  "city": "…",
  "postalCode": "…"
}`;

    const userPrompt = `Indice utilisateur (lang=${lang}):\n${hint}\n\nVille fournie: ${city || ''}\nCatégorie fournie: ${category || ''}`;

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
      // Fallback minimal si le JSON est invalide
      draft = {
        title: 'Nouvelle demande',
        description: `Je recherche: ${hint}`,
        category: category || 'Autre',
        city: city || '',
        postalCode: ''
      };
    }

    // Validation du format
    if (!draft.title || !draft.description) {
      throw new Error('Réponse IA invalide : titre ou description manquant');
    }

    console.log('[generateOfferDraft] success', {
      titleLen: (draft.title || '').length,
      descLen: (draft.description || '').length,
      category: draft.category || category || 'Autre',
      city: draft.city || city || ''
    });

    // Déduire le code postal à partir de la ville si non fourni par l'IA
    const finalCity = draft.city || city || '';
    let finalPostalCode = draft.postalCode || '';
    
    if (finalCity && !finalPostalCode) {
      finalPostalCode = findPostalCode(finalCity);
      console.log('[generateOfferDraft] Code postal déduit:', { city: finalCity, postalCode: finalPostalCode });
    }

    // Retourne le brouillon
    return {
      title: draft.title || '',
      description: draft.description || '',
      category: draft.category || category || 'Autre',
      city: finalCity,
      postalCode: finalPostalCode
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
