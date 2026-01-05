## ✅ Réparations Cloud Functions - Speech-to-Text + IA

### Problèmes trouvés et résolus:

1. **`transcribeAndDraftOffer` utilisait Vertex AI Gemini qui n'était pas configuré**
   - ❌ Ancien: Vertex AI GenAI + Speech-to-Text v2 (recognizer EU presto-default inexistant)
   - ✅ Nouveau: OpenAI GPT-4o-mini + Speech-to-Text v1 (API standard)

2. **Imports inutilisés supprimés**
   - ❌ Avant: `@google-cloud/vertexai`, `SpeechClient v2`, initialisation `const speech = new SpeechClient(...)`
   - ✅ Après: Uniquement `openai`, `speech-to-text v1` (simple)

3. **Fonction `safeJsonParse()` supprimée** 
   - Elle n'était utilisée que pour Gemini

### Architecture finale:

**2 Cloud Functions, toutes les 2 en `europe-west1`:**

1. **`generateOfferDraft(hint, city, category)`**
   - Input: Texte simple du besoin
   - Process: OpenAI GPT-4o-mini analyse le texte
   - Output: JSON structuré {title, description, category, city, postalCode}

2. **`transcribeAndDraftOffer(gcsUri, languageCode, category, city)`**
   - Input: URI Google Cloud Storage d'un fichier audio WAV
   - Process: 
     - Transcription via Speech-to-Text v1 (API simple)
     - Analyse du texte transcrit par OpenAI GPT-4o-mini
   - Output: {transcript, draft}

### Logique "Je recherche…" (backend)

- La fonction `generateOfferDraft` formate désormais la description en 1–2 phrases qui commencent par "Je recherche…" (style demande client), incluant métier, tâche et secteur/ville.
- Titre court (≤ 60 caractères), catégories limitées, ville et code postal si déductibles.
- Réponse strictement au format JSON (sans markdown). Fallback minimal si le JSON retourné est invalide.

### Déploiement:

```bash
cd /workspaces/presto_app
firebase deploy --only functions
firebase functions:log  # Voir les logs
```

### Frontend (Flutter):

Aucun changement - utilise `AiOfferService`:
- `generateDraft(hint, currentCity, currentCategory)` → appelle `generateOfferDraft`
- `transcribeAndDraft(gcsUri, languageCode, category, city)` → appelle `transcribeAndDraftOffer`

Région client: `FirebaseFunctions.instanceFor(region: 'europe-west1')`

### Dépendances requises:

- `openai: ^4.104.0` ✅
- `@google-cloud/speech: ^6.7.1` ✅ (v1 par défaut)
- `firebase-admin: ^13.6.0` ✅

### Test quick:

1. Aller sur https://stef25fwi.github.io → "Je publie"
2. Remplir/tester le micro 🎤
3. Parler: "Besoin de peindre le salon ce week-end"
4. Stop → devrait auto-fill titre/description
5. Si erreur: `firebase functions:log | grep -E "Error|STT|AI"`
