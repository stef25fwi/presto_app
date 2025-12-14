const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const OpenAI = require('openai');
const { SpeechClient } = require("@google-cloud/speech").v2;
const { VertexAI } = require("@google-cloud/vertexai");

initializeApp();

// IMPORTANT : endpoint EU pour utiliser locations/eu
const speech = new SpeechClient({ apiEndpoint: "eu-speech.googleapis.com" });

/**
 * Cloud Function qui génère un brouillon d'offre avec l'IA
 * 
 * Entrée : { hint, city, category, lang }
 * Sortie : { title, description, category, city, postalCode }
 */
exports.generateOfferDraft = onCall(async (request) => {
  const { hint, city, category, lang = 'fr' } = request.data;

  // Validation basique
  if (!hint || typeof hint !== 'string' || hint.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Le paramètre "hint" est requis');
  }

  // Initialiser OpenAI ici avec la clé d'environnement
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
  });

  try {
    // Prompt pour l'IA
    const systemPrompt = `Tu es un assistant qui aide à rédiger des annonces de services en Guadeloupe et en Martinique.
L'utilisateur décrit son besoin et tu dois générer :
- Un titre court et accrocheur (max 60 caractères)
- Une description détaillée et professionnelle (150-300 mots)
- La catégorie parmi : Jardinage, Bricolage, Ménage, Restauration / Extra, DJ / Sono, Baby-sitting, Transport / Livraison, Informatique, Autre
- La ville (si mentionnée, sinon garde "${city}" ou vide)
- Le code postal (si possible, sinon vide)

Réponds UNIQUEMENT avec un objet JSON valide (pas de markdown, pas de \`\`\`json) :
{
  "title": "...",
  "description": "...",
  "category": "...",
  "city": "...",
  "postalCode": "..."
}`;

    const userPrompt = `Besoin : ${hint}
Ville actuelle : ${city || 'non précisée'}
Catégorie suggérée : ${category || 'non précisée'}`;

    // Appel à l'API OpenAI
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini', // ou "gpt-4o" pour une meilleure qualité
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.7,
      max_tokens: 800
    });

    const responseText = completion.choices[0]?.message?.content?.trim();

    if (!responseText) {
      throw new Error('Pas de réponse de l\'IA');
    }

    // Parse le JSON (enlever les éventuels backticks markdown)
    let cleanedText = responseText;
    if (cleanedText.startsWith('```json')) {
      cleanedText = cleanedText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (cleanedText.startsWith('```')) {
      cleanedText = cleanedText.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }

    const draft = JSON.parse(cleanedText);

    // Validation du format
    if (!draft.title || !draft.description) {
      throw new Error('Réponse IA invalide : titre ou description manquant');
    }

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
// Fonction de transcription audio + rédaction avec Gemini
// ============================================================================

function safeJsonParse(text) {
  // Gemini peut parfois entourer de ```json ... ```
  const cleaned = text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
  return JSON.parse(cleaned);
}

exports.transcribeAndDraftOffer = onCall({ timeoutSeconds: 120 }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Connexion requise.");

  const {
    gcsUri,               // ex: "gs://bucket/stt/xxx.wav"
    languageCode = "fr-FR",
    category = "",
    city = "",
  } = req.data || {};

  if (!gcsUri) throw new HttpsError("invalid-argument", "gcsUri manquant.");

  // 1) Transcription premium (Speech-to-Text v2 + Chirp 3 + ponctuation)
  // IMPORTANT : utiliser locations/eu avec l'endpoint EU
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  const recognizer = `projects/${projectId}/locations/eu/recognizers/presto-default`;

  const [sttResp] = await speech.recognize({
    recognizer,
    config: {
      languageCodes: [languageCode],
      model: "chirp_3", // Chirp 3 = "chirp_3", dispo en STT v2
      features: { enableAutomaticPunctuation: true }, // ponctuation auto
      autoDecodingConfig: {},
    },
    audio: { uri: gcsUri },
  });

  const transcript = (sttResp.results || [])
    .flatMap(r => (r.alternatives || []).map(a => a.transcript || ""))
    .join("\n")
    .trim();

  if (!transcript) {
    throw new HttpsError("failed-precondition", "Transcription vide (audio trop court/bruité ?).");
  }

  // 2) Rédaction IA (Gemini via Vertex AI)
  const vertexLocation = process.env.PRESTO_VERTEX_LOCATION || "europe-west1";
  const vertexAI = new VertexAI({
    project: projectId,
    location: vertexLocation,
  });

  const prompt = `
Tu es un assistant de rédaction d'annonces pour une app de services (type Prestō).
À partir de la transcription brute, produis un JSON STRICT (pas de markdown) au format :

{
  "title": "…",
  "description": "…",            // texte propre, clair, pro
  "bullets": ["…","…","…"],       // 3 à 6 puces utiles
  "constraints": ["…","…"],       // contraintes / conditions (horaires, urgence, matériel, etc.)
  "category": "…",               // si tu peux déduire, sinon garde la valeur fournie
  "city": "…"                    // si tu peux déduire, sinon garde la valeur fournie
}

Règles IMPORTANTES :
- N'invente pas de téléphone, budget, prix, ou infos perso.
- Ne mentionne pas "Téléphone" ni "Budget".
- Garde la langue en français (fr-FR).
- Si une info manque, reste générique (ex: "date à préciser").
- Catégorie fournie: "${category}"
- Ville fournie: "${city}"

Transcription:
"""${transcript}"""
`;

  const model = vertexAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
  const gen = await model.generateContent(prompt);

  const response = await gen.response;
  const text = response.candidates[0]?.content?.parts[0]?.text || "";
  let draft;
  try {
    draft = safeJsonParse(text);
  } catch (e) {
    // fallback minimal si JSON pas parseable
    draft = {
      title: "Nouvelle offre",
      description: transcript,
      bullets: [],
      constraints: [],
      category: category || "",
      city: city || "",
    };
  }

  return {
    transcript,
    draft,
  };
});
