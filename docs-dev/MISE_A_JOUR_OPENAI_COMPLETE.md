# ✅ Mise à jour Cloud Function - Nouveau Prompt OpenAI

## Résumé des changements

Deux fichiers ont été modifiés pour intégrer le nouveau prompt OpenAI riche :

### 1️⃣ `functions/index.js` (Cloud Function)

#### Changement 1: Nouveau systemPrompt (lignes 181-206)
**Avant** (ancien format simple):
```javascript
const systemPrompt = `Tu écris des DEMANDES de services courtes...`;
```

**Après** (nouveau format riche):
```javascript
const systemPrompt = `Tu es un assistant rédactionnel pour l'application Prestō.
Objectif : transformer une transcription vocale brute en une annonce claire...
[format JSON complet avec 14 champs]`;
```

✅ **Impact**: OpenAI génère maintenant :
- titre + suggestions_titres
- budget (type, min, max)
- urgence
- details, competences_requises, materiel
- disponibilites
- questions_a_poser

#### Changement 2: Nouveau userPrompt (lignes 208-216)
**Avant**:
```javascript
const userPrompt = `Indice utilisateur (lang=${lang}):\n${hint}\n\nVille fournie: ${city || ''}\nCatégorie fournie: ${category || ''}`;
```

**Après**:
```javascript
const userPrompt = `Voici la transcription brute de l'utilisateur (peut contenir des erreurs) :
${hint}

Contexte (si dispo) :
- Ville détectée (si dispo) : ${city || 'Non détectée'}
- Catégorie choisie (si dispo) : ${category || 'Non spécifiée'}
- Langue : ${lang}

Génère l'annonce.`;
```

✅ **Impact**: Prompt plus clair et mieux structuré pour OpenAI

#### Changement 3: Parsing amélioré (lignes 245-265)
**Avant** (fallback minimal basé sur ancien format):
```javascript
draft = {
  title: 'Nouvelle demande',
  description: `Je recherche: ${hint}`,
  category: category || 'Autre',
  city: city || '',
  postalCode: ''
};
```

**Après** (fallback riche basé sur nouveau format):
```javascript
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
```

✅ **Impact**: Fallback structuré et robuste même si OpenAI échoue

#### Changement 4: Retour enrichi (lignes 284-305)
**Avant** (5 champs):
```javascript
return {
  title: draft.title || '',
  description: draft.description || '',
  category: draft.category || category || 'Autre',
  city: finalCity,
  postalCode: finalPostalCode
};
```

**Après** (19 champs = ancien + nouveau):
```javascript
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
```

✅ **Impact**: 
- ✅ Compatibilité 100% avec ancien code Dart
- ✅ Nouveau code Dart peut utiliser tous les nouveaux champs
- ✅ Pas de breaking change

---

### 2️⃣ `lib/services/ai_draft_service.dart` (Service Dart)

#### Changement 1: Ancien service conservé (lignes 3-36)
`generateOfferDraft()` reste inchangé pour compatibilité rétroactive.

✅ **Impact**: Tout le code existant continue à fonctionner

#### Changement 2: Nouveau service riche (lignes 38-92)
```dart
Future<Map<String, dynamic>> generateOfferDraftV2({
  required String text,
  String? city,
  String? category,
}) async {
  // Retourne tous les champs (ancien + nouveau)
  return {
    'title', 'category', 'description', 'location', 'postalCode',
    'titre', 'suggestions_titres', 'description_courte', 'categorie', 'ville',
    'secteur', 'budget', 'urgence', 'details', 'competences_requises',
    'materiel', 'disponibilites', 'questions_a_poser',
    'success'
  };
}
```

✅ **Impact**: 
- Nouveau code peut utiliser `generateOfferDraftV2()` pour accéder aux champs riches
- Anciens appels à `generateOfferDraft()` continuent à fonctionner

#### Changement 3: Helpers de conversion (lignes 94-137)
Ajout de 3 fonctions privées pour structurer les données :
- `_toStringList()` : Convertit dynamic → List<String>
- `_toBudgetMap()` : Convertit dynamic → Map structuré de budget
- `_toMaterielMap()` : Convertit dynamic → Map structuré de matériel

✅ **Impact**: 
- Gestion robuste des types Dart
- Pas de risque de crash si OpenAI retourne des types inattendus

---

## 🔄 Flux d'utilisation

### Code existant (inchangé, continue à fonctionner)
```dart
final draft = await _aiService.generateOfferDraft(text: text);
if (draft['success'] == true) {
  _titleController.text = draft['title'];
  _category = draft['category'];
  _descriptionController.text = draft['description'];
}
```

### Nouveau code (utilise les champs riches)
```dart
final draft = await _aiService.generateOfferDraftV2(
  text: text,
  city: currentCity,
  category: currentCategory,
);
if (draft['success'] == true) {
  // Utiliser les nouveaux champs
  _titleController.text = draft['titre'];
  _suggestedTitles = draft['suggestions_titres'] as List<String>;
  _budget = draft['budget'] as Map<String, dynamic>;
  _questions = draft['questions_a_poser'] as List<String>;
}
```

---

## ✅ Vérification de compatibilité

| Aspect | Avant | Après | Status |
|--------|-------|-------|--------|
| Fonction Cloud | `generateOfferDraft` | `generateOfferDraft` | ✅ Même nom |
| Service Dart ancien | `generateOfferDraft()` | `generateOfferDraft()` | ✅ Préservé |
| Service Dart nouveau | N/A | `generateOfferDraftV2()` | ✅ Ajouté |
| Retour simplifié | 5 champs | 19 champs | ✅ Surensemble |
| Fallback | Minimal | Riche | ✅ Meilleur |
| Code existant | Fonctionne | Fonctionne | ✅ 100% compatible |

---

## 🚀 Tests recommandés

### 1. Test simple (ancien code)
```dart
final text = "je veux tondre mon jardin à baie mahault";
final draft = await _aiService.generateOfferDraft(text: text);
assert(draft['success'] == true);
assert(draft['title'].isNotEmpty);
assert(draft['category'].isNotEmpty);
```

### 2. Test riche (nouveau code)
```dart
final draft = await _aiService.generateOfferDraftV2(
  text: "je veux tondre mon jardin à baie mahault",
  city: "Baie-Mahault",
  category: "Jardinage",
);
assert(draft['success'] == true);
assert(draft['titre'].isNotEmpty);
assert(draft['suggestions_titres'].isNotEmpty);
assert(draft['questions_a_poser'].isNotEmpty);
```

### 3. Test budget
```dart
final draft = await _aiService.generateOfferDraftV2(text: "...");
final budget = draft['budget'] as Map<String, dynamic>;
assert(budget.containsKey('type'));
assert(budget.containsKey('min'));
assert(budget.containsKey('max'));
```

### 4. Test questions
```dart
final draft = await _aiService.generateOfferDraftV2(text: "...");
final questions = draft['questions_a_poser'] as List<String>;
// Afficher les questions pour compléter l'annonce
```

---

## 📊 Comparaison des prompts

### Ancien prompt (limité)
```
Tu écris des DEMANDES de services courtes...
Réponds UNIQUEMENT avec un objet JSON valide :
{
  "title": "…",
  "description": "Je recherche …",
  "category": "…",
  "city": "…",
  "postalCode": "…"
}
```
❌ 5 champs seulement
❌ Pas de budget
❌ Pas d'urgence
❌ Pas de questions

### Nouveau prompt (riche)
```
Tu es un assistant rédactionnel pour l'application Prestō...
FORMAT JSON (obligatoire) :
{
  "titre": string,
  "suggestions_titres": [string, string],
  "categorie": string|null,
  "ville": string|null,
  "secteur": string|null,
  "budget": { "type": "fixe"|"horaire"|null, "min": number|null, "max": number|null, "devise": "EUR" },
  "urgence": "immediat"|"24h"|"7j"|"flexible"|null,
  "description_courte": string,
  "details": [string],
  "competences_requises": [string],
  "materiel": { "fourni_par_demandeur": [string], "a_prevoir_par_prestataire": [string] },
  "disponibilites": string|null,
  "questions_a_poser": [string]
}
```
✅ 14 champs structurés
✅ Budget détaillé
✅ Urgence détectée
✅ Questions intelligentes
✅ Matériel clarifié

---

## ⚠️ Points importants

1. **Pas de breaking change** : Code existant fonctionne tel quel
2. **Opt-in** : Utiliser `generateOfferDraftV2()` pour accéder aux nouveaux champs
3. **Backward compatible** : Cloud Function retourne les deux formats
4. **Robuste** : Fallback si OpenAI échoue
5. **Type-safe** : Helpers de conversion en Dart

---

## 🎯 Prochaines étapes

1. ✅ Cloud Function mise à jour avec nouveau prompt
2. ✅ Service Dart supportant ancien + nouveau format
3. ⏳ Tester E2E (Firebase emulator)
4. ⏳ Mettre à jour UI pour afficher suggestions_titres
5. ⏳ Mettre à jour UI pour afficher questions_a_poser
6. ⏳ Gérer budget dans le formulaire
7. ⏳ Déployer sur Firebase

