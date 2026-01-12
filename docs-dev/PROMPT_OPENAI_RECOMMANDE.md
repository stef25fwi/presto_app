# Prompt OpenAI Recommandé - Format JSON Riche

## 📋 Vue d'ensemble

Ce nouveau prompt génère un JSON complet et structuré pour un meilleur auto-remplissage des annonces. Il remplace l'ancien prompt simple par une version professionnelle.

---

## 🎯 SYSTEM PROMPT (à utiliser)

```
Tu es un assistant rédactionnel pour l'application Prestō.
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
}
```

---

## 👤 USER PROMPT (à adapter avec contexte)

```
Voici la transcription brute de l'utilisateur (peut contenir des erreurs) :
<<<TRANSCRIPTION>>>

Contexte (si dispo) :
- Région/Département : <<<REGION>>>
- Ville détectée (si dispo) : <<<VILLE_DETECTEE>>>
- Catégorie choisie (si dispo) : <<<CATEGORIE_UI>>>

Génère l'annonce.
```

---

## 📊 Comparaison : Ancien vs Nouveau Format

### Ancien format (actuel)
```json
{
  "title": "Besoin d'un jardinier",
  "description": "Je recherche quelqu'un pour tondre mon jardin",
  "category": "Jardinage",
  "city": "Baie-Mahault",
  "postalCode": "97122"
}
```
❌ Trop limité, ne capture pas les nuances

### Nouveau format (recommandé)
```json
{
  "titre": "Tondre mon jardin à Baie-Mahault",
  "suggestions_titres": [
    "Besoin d'un jardinier pour tondre",
    "Tondre le gazon - Baie-Mahault"
  ],
  "categorie": "Jardinage",
  "ville": "Baie-Mahault",
  "secteur": "Entretien extérieur",
  "budget": {
    "type": "fixe",
    "min": 50,
    "max": 100,
    "devise": "EUR"
  },
  "urgence": "7j",
  "description_courte": "Je cherche quelqu'un pour tondre mon jardin à Baie-Mahault. Surface d'environ 500m².",
  "details": [
    "Surface : ~500m²",
    "Terrain en pente douce",
    "Accès voiture facile"
  ],
  "competences_requises": [
    "Tondre le gazon",
    "Débroussailler",
    "Évacuer les herbes coupées"
  ],
  "materiel": {
    "fourni_par_demandeur": [],
    "a_prevoir_par_prestataire": ["Tondeuse", "Débroussailleuse", "Sac à herbe"]
  },
  "disponibilites": "Samedi ou dimanche après-midi",
  "questions_a_poser": [
    "Faut-il évacuer complètement les herbes ?",
    "Avez-vous des plantes à préserver ?",
    "Frequence : une fois, ou régulier ?"
  ]
}
```
✅ Riche, détaillé, aide à générer une meilleure annonce

---

## 🔄 Intégration dans le Cloud Function

### Option 1: Remplacer le prompt dans `functions/index.js`

Remplacer ceci (lignes 173-197):
```javascript
const systemPrompt = `Tu écris des DEMANDES de services courtes...`;
```

Par ceci:
```javascript
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
```

### Option 2: User Prompt à adapter

Remplacer ceci (ligne 209):
```javascript
const userPrompt = `Indice utilisateur (lang=${lang}):\n${hint}\n\nVille fournie: ${city || ''}\nCatégorie fournie: ${category || ''}`;
```

Par ceci:
```javascript
const userPrompt = `Voici la transcription brute de l'utilisateur (peut contenir des erreurs) :
${hint}

Contexte (si dispo) :
- Région/Département : ${region || 'Non spécifiée'}
- Ville détectée (si dispo) : ${city || 'Non détectée'}
- Catégorie choisie (si dispo) : ${category || 'Non spécifiée'}
- Langue : ${lang}

Génère l'annonce.`;
```

---

## 🎨 Exemple d'utilisation complète

### Requête
```javascript
{
  "hint": "euh je cherche quelqu'un pour m'aider à peindre ma maison à petit bourg enfin je sais pas trop quoi faire avec les murs qui sont un peu dégradés",
  "city": "Petit-Bourg",
  "category": "Bricolage",
  "lang": "fr"
}
```

### Réponse OpenAI (nouveau format)
```json
{
  "titre": "Peindre ma maison à Petit-Bourg",
  "suggestions_titres": [
    "Besoin d'aide pour la peinture intérieure",
    "Rénover les murs dégradés"
  ],
  "categorie": "Bricolage",
  "ville": "Petit-Bourg",
  "secteur": "Peinture / Rénovation",
  "budget": {
    "type": null,
    "min": null,
    "max": null,
    "devise": "EUR"
  },
  "urgence": "flexible",
  "description_courte": "Je cherche quelqu'un pour m'aider à peindre ma maison à Petit-Bourg. Les murs sont dégradés et nécessitent une rénovation.",
  "details": [
    "Murs dégradés à rénover",
    "Besoin d'aide pour l'organisation du projet"
  ],
  "competences_requises": [
    "Peinture intérieure",
    "Préparation des surfaces",
    "Conseil en rénovation"
  ],
  "materiel": {
    "fourni_par_demandeur": [],
    "a_prevoir_par_prestataire": ["Peinture", "Pinceaux/Rouleaux", "Échafaudage/Escabeau"]
  },
  "disponibilites": null,
  "questions_a_poser": [
    "Quel est votre budget approximatif ?",
    "Quelle est la surface à peindre ?",
    "Quand souhaitez-vous commencer ?",
    "Avez-vous une préférence de couleur ?",
    "Avez-vous besoin de conseil en design ?"
  ]
}
```

---

## ⚙️ Ajustements recommandés pour le Dart

### Ancien service (simple)
```dart
Future<Map<String, dynamic>> generateOfferDraft({required String text})
```

### Nouveau service (riche)
```dart
Future<Map<String, dynamic>> generateOfferDraftV2({
  required String text,
  String? city,
  String? category,
  String? region,
})
```

**Mapping des champs Dart**:
```dart
{
  'titre': String,
  'suggestions_titres': List<String>,
  'categorie': String?,
  'ville': String?,
  'secteur': String?,
  'budget': {
    'type': String?, // "fixe", "horaire", null
    'min': int?,
    'max': int?,
    'devise': String,
  },
  'urgence': String?, // "immediat", "24h", "7j", "flexible", null
  'description_courte': String,
  'details': List<String>,
  'competences_requises': List<String>,
  'materiel': {
    'fourni_par_demandeur': List<String>,
    'a_prevoir_par_prestataire': List<String>,
  },
  'disponibilites': String?,
  'questions_a_poser': List<String>,
}
```

---

## 📝 Champs explicités

| Champ | Type | Description |
|-------|------|-------------|
| `titre` | string | Titre court et accrocheur (max 60 chars) |
| `suggestions_titres` | string[] | 2 alternatives si ambiguïté |
| `categorie` | string\|null | Catégorie (Jardinage, Bricolage, etc.) |
| `ville` | string\|null | Ville détectée |
| `secteur` | string\|null | Sous-catégorie (ex: "Peinture / Rénovation") |
| `budget.type` | "fixe"\|"horaire"\|null | Type de tarification |
| `budget.min` | number\|null | Budget minimum en EUR |
| `budget.max` | number\|null | Budget maximum en EUR |
| `budget.devise` | "EUR" | Devise (toujours EUR) |
| `urgence` | "immediat"\|"24h"\|"7j"\|"flexible"\|null | Urgence du besoin |
| `description_courte` | string | Résumé 1-2 phrases |
| `details` | string[] | Points spécifiques du besoin |
| `competences_requises` | string[] | Savoir-faire nécessaire |
| `materiel.fourni_par_demandeur` | string[] | Outils fournis par le client |
| `materiel.a_prevoir_par_prestataire` | string[] | Outils à prévoir |
| `disponibilites` | string\|null | Créneau temporel |
| `questions_a_poser` | string[] | Questions à clarifier avec le client |

---

## ✅ Avantages du nouveau format

1. **Auto-remplissage amélioré** : Plus de champs = meilleure couverture UI
2. **Suggestion de titres** : L'utilisateur peut choisir la meilleure formulation
3. **Budget structuré** : Type (fixe/horaire), min/max
4. **Détails pertinents** : Liste de points importants
5. **Matériel clarifié** : Ce que le prestataire apporte vs. le client
6. **Questions intelligentes** : Aide à compléter l'annonce
7. **Urgence détectée** : Contexte temporel du besoin

---

## 🚀 Prochaines étapes

1. ✅ Valider ce prompt avec quelques tests
2. ⏳ Mettre à jour `functions/index.js` avec le nouveau prompt
3. ⏳ Créer/mettre à jour `AiDraftServiceV2` pour gérer le nouveau JSON
4. ⏳ Adapter l'UI Dart pour afficher les suggestions_titres, budget, questions, etc.
5. ⏳ Tester le flux complet E2E

