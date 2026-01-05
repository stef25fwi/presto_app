# Système de Cache Boîte à Outils (Toolbox Cache)

## Vue d'ensemble

Système intelligent de cache Firestore pour éviter les appels répétés à l'IA lors de la génération de parcours. 

**Concept** : Chaque parcours généré est enregistré avec ses critères (type_projet, domaine, région). Si un autre utilisateur crée un parcours avec les mêmes critères, on retourne la version en cache au lieu de régénérer.

---

## Architecture

### Collections Firestore

#### 1. `/toolbox_journeys/{journeyId}`
Stockage des parcours générés complets.

**Schéma** :
```
{
  "type_projet": "Prestation de services",
  "domaine": "Consulting",
  "region": "Île-de-France",
  "criteria_hash": "Prestation de services|Consulting|Île-de-France",
  "generated_at": <Timestamp>,
  "content": {
    "recommendation": {...},
    "blockingAlerts": [...],
    "costs": {...},
    "plan30": [...],
    "aides": [...]
  }
}
```

#### 2. `/toolbox_journey_index/{indexId}`
Table d'index pour accès rapide par critères.

**Schéma** :
```
{
  "criteria_hash": "Prestation de services|Consulting|Île-de-France",
  "journey_id": "<documentId dans toolbox_journeys>",
  "created_at": <Timestamp>
}
```

---

## Flux de données

### Scenario 1 : Première génération (Cache Miss)
```
Utilisateur A
  ↓
Entre critères (type_projet, domaine, région)
  ↓
ToolboxCacheService.fetchExistingJourney()
  ↓
Pas trouvé en cache (index vide)
  ↓
Appel IA → génération du parcours
  ↓
ToolboxCacheService.saveNewJourney()
  ↓
Créer /toolbox_journeys/{journeyId}
Créer /toolbox_journey_index/{indexId}
  ↓
Afficher le parcours à l'utilisateur
```

### Scenario 2 : Accès suivant (Cache Hit)
```
Utilisateur B
  ↓
Entre **mêmes critères** que l'utilisateur A
  ↓
ToolboxCacheService.fetchExistingJourney()
  ↓
Trouvé en index → récupère journey_id
  ↓
Charge /toolbox_journeys/{journeyId}
  ↓
Retourne le parcours en cache
  ↓
❌ **Pas d'appel IA** ✅
```

---

## Critères de matching

Un parcours est considéré comme identique si :
- `type_projet` identique (ex: "Prestation de services")
- `domaine` identique (ex: "Consulting")
- `region` identique (ex: "Île-de-France")

**Format de hash** : `type_projet|domaine|region`

Exemple : `Prestation de services|Consulting|Île-de-France`

---

## Implémentation

### Service principal : `ToolboxCacheService`

Fichier : `lib/services/toolbox_cache_service.dart`

**Méthodes principales** :

#### `fetchExistingJourney()`
Cherche un parcours existant pour les critères donnés.
```dart
final journey = await cacheService.fetchExistingJourney(
  typeProjet: 'Prestation de services',
  domaine: 'Consulting',
  region: 'Île-de-France',
);
// Retourne Map<String, dynamic>? ou null
```

#### `saveNewJourney()`
Sauvegarde un parcours généré et crée les index.
```dart
final journeyId = await cacheService.saveNewJourney(
  typeProjet: 'Prestation de services',
  domaine: 'Consulting',
  region: 'Île-de-France',
  journeyContent: {
    'recommendation': {...},
    'blockingAlerts': [...],
    // ...
  },
);
```

#### `deleteJourney()` (maintenance)
Supprime un parcours et son index associé.
```dart
await cacheService.deleteJourney(
  journeyId: 'xyz123',
  criteriaHash: 'Prestation de services|Consulting|Île-de-France',
);
```

#### `getCacheStats()`
Retourne le nombre de parcours uniques en cache.
```dart
final count = await cacheService.getCacheStats();
```

---

## Intégration dans `ToolboxJeMeLancePage`

### Modification 1 : Import du service
```dart
import 'package:presto_app/services/toolbox_cache_service.dart';

class _ToolboxJeMeLancePageState extends State<ToolboxJeMeLancePage> {
  final _cacheService = ToolboxCacheService();
  bool _isFromCache = false; // Flag pour indiquer source
  // ...
}
```

### Modification 2 : Nouvelle méthode `_recomputeDerivedWithCache()`
```dart
Future<void> _recomputeDerivedWithCache() async {
  final cachedJourney = await _cacheService.fetchExistingJourney(
    typeProjet: _activityType,
    domaine: _projectCtrl.text.trim(),
    region: _region,
  );

  if (cachedJourney != null) {
    // Cache hit
    _isFromCache = true;
    _importDerived(cachedJourney['content'] as Map<String, dynamic>? ?? {});
  } else {
    // Cache miss → générer + sauvegarder
    _isFromCache = false;
    final r = _computeRecommendationRules();
    // ... traitement ...
    
    // Sauvegarder en cache
    await _cacheService.saveNewJourney(
      typeProjet: _activityType,
      domaine: _projectCtrl.text.trim(),
      region: _region,
      journeyContent: {...},
    );
  }
}
```

### Modification 3 : Appel au cache dans `_saveDraft()`
```dart
Future<void> _saveDraft({bool recompute = true}) async {
  // ...
  if (recompute) {
    // Si critères remplis, utiliser le cache
    if (_projectCtrl.text.trim().isNotEmpty && _region.isNotEmpty) {
      await _recomputeDerivedWithCache();
    } else {
      _recomputeDerived();
    }
  }
  // ...
}
```

---

## Avantages

✅ **Réduction des appels IA**
- Pas d'appel OpenAI/Gemini si parcours existe
- Économies coûts API (tokens)

✅ **Expérience utilisateur**
- Temps de réponse instantané si cache hit
- Pas d'attente lors de la génération IA

✅ **Données partagées intelligemment**
- Tous les utilisateurs bénéficient du cache global
- Enrichissement progressif du cache

✅ **Flexibilité**
- Cache optionnel (fallback sur génération directe)
- Facile à désactiver ou modifier les critères

---

## Considérations

### Fraîcheur des données
- Parcours générés ne sont jamais mis à jour
- Si recommandations IA évoluent, anciens parcours restent figés
- **Solution future** : versionning avec date d'expiration

### Critères de matching
- Peut être trop restrictif (3 critères) ou trop permissif
- **Considérer** : ajouter situation / ambition / CA visé ?
- Tester empiriquement l'impact sur cache hit rate

### Confidentialité
- Collections `toolbox_journeys` et `toolbox_journey_index` sont **publiques en lecture**
- Tous les parcours sont visibles par tous (pas d'UID utilisateur)
- ✅ C'est voulu (parcours génériques, pas perso)

### Scalabilité
- Pour milliers de parcours : indexer sur `criteria_hash`
- Pour millions : considérer shard par domaine ou région

---

## Monitoring

### Ajouter des logs

```dart
debugPrint('✅ Parcours trouvé en cache');
debugPrint('❌ Parcours non trouvé, génération lancée');
debugPrint('💾 Parcours sauvegardé: $journeyId');
```

### Dashboard Firestore
Consulter dans Firebase Console :
- Nombre de docs dans `/toolbox_journeys`
- Nombre de docs dans `/toolbox_journey_index`
- Taille totale de la collection

---

## Prochaines étapes

1. **Tester empiriquement** le taux de hit du cache
2. **Monitorer** les temps de réponse (cache vs génération)
3. **Ajouter versionning** pour gérer les évolutions IA
4. **Enrichir critères** si hit rate insuffisant
5. **Implémenter TTL** (expiration) si parcours doivent viellir

---

## Fichiers associés

- `lib/services/toolbox_cache_service.dart` - Service de cache
- `lib/pages/toolbox_je_me_lance_page.dart` - Page intégrant le cache
- `docs/TOOLBOX_CACHE_FIRESTORE_RULES.txt` - Rules Firestore
- `docs/TOOLBOX_CACHE_README.md` - Ce fichier
