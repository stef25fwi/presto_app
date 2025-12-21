# Résumé des Paramètres OpenAI - Bouton IA "Je Publie une Offre"

## Configuration Firebase
- **Région**: `europe-west1`
- **Secret requis**: `OPENAI_API_KEY` (à configurer avec `firebase functions:secrets:set OPENAI_API_KEY`)
- **Package OpenAI**: `openai: ^4.104.0`

## Fonction Cloud: `generateOfferDraft`

### Paramètres d'entrée (requête)
```javascript
{
  "hint": String,           // Texte transcrit ou saisi (requis)
  "city": String,           // Ville fournie par l'utilisateur (optionnel)
  "category": String,       // Catégorie fournie par l'utilisateur (optionnel)
  "lang": String            // Langue (défaut: 'fr')
}
```

### Configuration OpenAI
- **Modèle**: `gpt-4o-mini`
- **Temperature**: `0.4` (réponses déterministes)
- **Max tokens**: `600`
- **Région**: `europe-west1`

### Système de Prompt
**Rôle**: Rédaction de demandes de services courtes pour des particuliers en Guadeloupe et en Martinique

**Caractéristiques**:
- Titre accrocheur (max 60 caractères)
- Description 1-2 phrases commençant par "Je recherche…"
- Gère les erreurs de transcription vocale (reconnaissance vocale)
- Déduit intelligemment la ville et la catégorie
- Catégories autorisées:
  - Jardinage
  - Bricolage
  - Ménage
  - Restauration / Extra
  - DJ / Sono
  - Baby-sitting
  - Transport / Livraison
  - Informatique
  - Autre

**Villes supportées** (Guadeloupe et Martinique):
- Guadeloupe: Baie-Mahault, Les Abymes, Pointe-à-Pitre, Le Gosier, Sainte-Anne, Saint-François, Petit-Bourg, Lamentin, Capesterre-Belle-Eau, Basse-Terre, etc.
- Martinique: Fort-de-France, Le Lamentin, Schoelcher, Le Robert, Le François, Le Marin, Les Trois-Îlets, Sainte-Luce, Sainte-Anne, La Trinité, etc.

### Paramètres de sortie
```javascript
{
  "title": String,          // Titre généré par l'IA
  "description": String,    // Description (commence par "Je recherche…")
  "category": String,       // Catégorie détectée ou fournie
  "city": String,           // Ville détectée ou fournie
  "postalCode": String      // Code postal (déduit automatiquement)
}
```

## Service Dart: `AiDraftService`

### Fonction publique
```dart
Future<Map<String, dynamic>> generateOfferDraft({required String text})
```

**Mapping des paramètres**:
- Input Dart: `text` → Output Cloud Function: `hint`
- Output Cloud Function: `city` → Input Dart: `location`

**Retour**:
```dart
{
  'title': String,
  'category': String,
  'description': String,
  'location': String,      // Correspond à 'city' du backend
  'postalCode': String,
  'success': bool,
  'error': String?,        // Si error
  'code': String?          // Code d'erreur FirebaseFunctionsException
}
```

## Intégration dans la Page "Je Publie"

### Emplacement UI
- **Composant**: `PremiumAiButton`
- **Label**: "Décrire mon besoin (IA)"
- **Localisation**: Section "Détail de votre besoin" (haut de la page)
- **État**: Dépend de `_isAnalyzing` (loading) et `_isListening` (enregistrement)

### Flux d'utilisation
1. Utilisateur clique sur `PremiumAiButton`
2. Démarre l'enregistrement audio via `_startMic()`
3. Enregistrement avec indicateur de pulsation
4. Transcription (locale STT ou premium via Chirp 3)
5. Appel à `generateOfferDraft()` via `AiDraftService`
6. Remplissage automatique des champs:
   - `_titleController.text`
   - `_category` + `_selectedSubCategory`
   - `_descriptionController.text`
   - `_city` (détecté de la location)
   - Code postal (optionnel)

### Gestion des erreurs
- Validation du texte transcrit
- Parsing JSON avec fallback minimal
- Gestion des exceptions Firebase (`FirebaseFunctionsException`)
- Affichage des snackbars d'erreur

## Configuration requise

### Avant déploiement
```bash
# Définir la clé API OpenAI
firebase functions:secrets:set OPENAI_API_KEY=sk-your-actual-key

# Vérifier la configuration
firebase functions:config:get
firebase functions:secrets:list
```

### Dépendances Dart
```yaml
cloud_functions: ^4.0.0 ou plus récent
```

### Dépendances Node.js
```json
{
  "openai": "^4.104.0"
}
```

## Notes importantes

1. **Clés API sensibles**: La clé OpenAI est stockée dans les secrets Firebase, pas en dur
2. **Coût**: Le modèle `gpt-4o-mini` est le plus économique pour cette tâche
3. **Temps de réponse**: Généralement < 1 seconde avec temperature 0.4
4. **Erreurs de transcription**: Le prompt gère intelligemment les fautes de reconnaissance vocale
5. **Déduction géographique**: Automatique via la fonction `findPostalCode()` si la ville est reconnue
