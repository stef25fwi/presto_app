const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const OpenAI = require('openai');

initializeApp();

// Secrets (Firebase Functions v2)
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');

/**
 * Cloud Function qui génère un brouillon d'offre avec l'IA
 * 
 * Entrée : { hint, city, category, lang }
 * Sortie : { title, description, category, city, postalCode }
 */
exports.generateOfferDraft = onCall({ region: 'europe-west1', secrets: [OPENAI_API_KEY] }, async (request) => {
  const { hint, city, category, lang = 'fr' } = request.data;

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

Contraintes et champs :
- Titre : court, accrocheur, max 60 caractères.
- Description : 1–2 phrases, commence par "Je recherche…".
- Catégories autorisées : Jardinage, Bricolage, Ménage, Restauration / Extra, DJ / Sono, Baby-sitting, Transport / Livraison, Informatique, Autre.
- Ville : si non déduite du texte, conserve "${city || ''}" ou vide.
- Code postal : si connu, sinon vide.

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

    // Retourne le brouillon
    return {
      title: draft.title || '',
      description: draft.description || '',
      category: draft.category || category || 'Autre',
      city: draft.city || city || '',
      postalCode: draft.postalCode || ''
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
  if (!req.auth) throw new HttpsError("unauthenticated", "Connexion requise.");

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
    const transcript = (response.results || [])
      .map(r => (r.alternatives?.[0]?.transcript || ""))
      .join("\n")
      .trim();

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

    console.log("[DONE] Returning transcript + draft");
    return {
      transcript,
      draft,
    };

  } catch (error) {
    console.error('[transcribeAndDraftOffer] Error:', error);
    throw new HttpsError('internal', `Erreur transcription : ${error.message}`);
  }
});
