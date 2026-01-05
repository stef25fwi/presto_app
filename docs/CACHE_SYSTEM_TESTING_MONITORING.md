# Cache System - Testing & Monitoring Guide

## Overview

Système de monitoring pour tracer le `hit rate` du cache Firestore pour les journeys boîte à outils.

**Objectif** : Mesurer l'efficacité du cache et optimiser les critères de matching.

---

## Architecture

### 3 composants:

1. **`ToolboxCacheService`** 
   - Gère fetch/save journeys
   - Appelle `CacheMonitoringService` à chaque accès

2. **`CacheMonitoringService`** (singleton)
   - Collecte metrics (hits/misses/errors)
   - Calcule hit rate
   - Sauvegarde en Firestore

3. **`CacheMetricsDashboard`** (widget)
   - Affiche les metrics en temps réel
   - Actions: print / save / reset

---

## Metrics collectées

| Metric | Description |
|--------|-------------|
| `total_requests` | Nombre total d'accès au cache |
| `cache_hits` | Requêtes servies par le cache |
| `cache_misses` | Requêtes nécessitant génération |
| `cache_errors` | Erreurs d'accès |
| `hit_rate` | % de requêtes servies par cache |
| `miss_rate` | % de requêtes nécessitant génération |
| `avg_access_time` | Temps moyen pour accéder au cache |

---

## Accéder au Dashboard en debug

### Option 1: Via Admin Space

```dart
// Dans admin_space_page.dart ou equivalent
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const CacheMetricsDashboard()),
);
```

### Option 2: Via debug menu

Ajouter bouton flottant temporaire en dev:

```dart
// Dans main.dart, build method
floatingActionButton: kDebugMode 
  ? FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CacheMetricsDashboard()),
      ),
      child: const Icon(Icons.analytics),
    )
  : null,
```

### Option 3: Logs console

```dart
final monitoring = CacheMonitoringService();
monitoring.printMetrics();  // Affiche les metrics formatées
```

---

## Test scenarios

### Test 1: Cache Miss → Hit

**Objectif** : Vérifier qu'un miss génère bien un parcours et le prochaine requête avec même critères est un hit.

**Steps** :
1. Ouvrir ToolboxJeMeLancePage
2. Entrer: type_projet="Prestation", domaine="Web", région="Île-de-France"
3. Observer console: `⚠️ Cache MISS (XXXms) - Génération lancée`
4. Attendre génération
5. **Reprendre l'app** (reload)
6. Entrer **mêmes critères**
7. Observer console: `✅ Cache HIT (XXXms)`
8. Comparer temps: HIT devrait être 10-50x plus rapide que MISS

**Expected output**:
```
⚠️ Cache MISS (2500ms) - Génération lancée
✅ Cache HIT (45ms)
```

---

### Test 2: Different criteria → Miss

**Objectif** : Vérifier que critères différents déclenchent un nouveau MISS.

**Steps** :
1. Entrer: "Prestation | Web | Île-de-France" → MISS (génération)
2. Changer région: "Prestation | Web | **Provence**" → MISS (nouveau parcours)
3. Revenir à "Île-de-France" → HIT (retrouvé en cache)

**Expected output**:
```
⚠️ Cache MISS (2500ms) - Génération lancée
⚠️ Cache MISS (2500ms) - Génération lancée
✅ Cache HIT (45ms)
```

---

### Test 3: Hit Rate Analytics

**Objectif** : Mesurer le hit rate sur plusieurs sessions.

**Steps** :
1. Ouvrir Dashboard
2. Effectuer 10 requêtes avec:
   - 3 requêtes critères A → 1 MISS + 2 HIT
   - 3 requêtes critères B → 1 MISS + 2 HIT  
   - 3 requêtes critères C → 1 MISS + 2 HIT
   - 1 requête critères A → 1 HIT
3. Vérifier Dashboard:
   - Total requests: 10
   - Hits: 7
   - Misses: 3
   - Hit rate: 70%

**Expected output**:
```
Total requests: 10
Hits: 7
Misses: 3
Hit rate: 70.0%
Miss rate: 30.0%
```

---

### Test 4: Error handling

**Objectif** : Vérifier que les erreurs Firestore sont bien loggées.

**Setup** :
- Simuler une erreur Firestore
- Lancer une requête cache

**Expected output**:
```
❌ Cache ERROR: Firestore permission denied
```

---

## Monitoring en production

### 1. Metrics Firestore

Les metrics sont sauvegardées en `/cache_analytics`:

```
{
  "timestamp": 2026-01-05T14:30:22Z,
  "metrics": {
    "total_requests": 100,
    "cache_hits": 75,
    "cache_misses": 25,
    "cache_errors": 0,
    "hit_rate_percent": "75.00",
    "miss_rate_percent": "25.00",
    "avg_access_time_ms": 120
  },
  "session_duration": "2026-01-05T14:30:22.123456"
}
```

### 2. Dashboard en production

Ajouter bouton dans Admin Space:

```dart
TextButton.icon(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CacheMetricsDashboard()),
  ),
  icon: const Icon(Icons.analytics),
  label: const Text('Cache Metrics'),
),
```

### 3. Analyze 24h stats

```dart
final monitoring = CacheMonitoringService();
final stats = await monitoring.getLast24hStats();
print('Hit rate 24h: ${stats?['hit_rate']}%');
```

---

## Interprétation des résultats

### Hit rate idéal

| Hit rate | Interprétation | Action |
|----------|---|---|
| **< 20%** | Cache peu efficace | Réviser critères de matching |
| **20-40%** | Cache moyennement efficace | Ajouter plus de critères (ex: ville) |
| **40-60%** | Cache bon | Status quo, monitorer |
| **> 60%** | Cache très efficace | Idéal ✅ |

### Temps d'accès

| Temps | Type | Acceptable |
|------|------|---|
| 30-50ms | Cache HIT | ✅ |
| 1000-3000ms | Cache MISS (génération) | ✅ |
| 5+ sec | MISS trop long | Optimiser génération |
| 200+ ms | HIT trop long | Vérifier Firestore |

---

## Optimization ideas

Si hit rate insuffisant:

### Idea 1: Ajouter plus de critères
```dart
// Actuellement: type_projet | domaine | région
// Future: type_projet | domaine | région | situation | ambition
```

### Idea 2: Réduire précision des critères
```dart
// Actuellement: "Île-de-France"
// Future: "Île-de-France"  →  "Île-de-France (Région)" (grouper départements)
```

### Idea 3: Cache hiérarchique
```dart
// Si pas trouvé pour (A, B, C), chercher (A, B, *)
// Fallback à (A, *, *) etc.
```

### Idea 4: Expiration + refresh
```dart
// Ajouter TTL: parcours > 30j = expiré = nouvelle génération
// Mais garder en cache si nouveau pareil
```

---

## Code samples

### Appeler monitoring manuellement

```dart
import 'package:presto_app/services/cache_monitoring_service.dart';

final monitoring = CacheMonitoringService();

// Enregistrer un hit
monitoring.recordCacheHit(Duration(milliseconds: 45));

// Enregistrer un miss
monitoring.recordCacheMiss(Duration(milliseconds: 2500));

// Afficher les metrics
monitoring.printMetrics();

// Sauvegarder en Firestore
await monitoring.saveMetricsToFirestore();

// Récupérer stats 24h
final stats = await monitoring.getLast24hStats();
print('Hit rate: ${stats?['hit_rate']}%');
```

### Intégrer dans _recomputeDerivedWithCache

```dart
final startTime = DateTime.now();

final cachedJourney = await _cacheService.fetchExistingJourney(
  typeProjet: _activityType,
  domaine: _projectCtrl.text.trim(),
  region: _region,
);

if (cachedJourney != null) {
  // ✅ Hit - monitoring enregistré automatiquement
  _isFromCache = true;
  _importDerived(cachedJourney['content'] as Map<String, dynamic>? ?? {});
} else {
  // ⚠️ Miss - génération
  _isFromCache = false;
  final r = _computeRecommendationRules();
  // ... process ...
  
  final generationTime = DateTime.now().difference(startTime);
  _cacheService.recordCacheMiss(generationTime);  // Enregistrer le miss
}
```

---

## Troubleshooting

### Hit rate = 0%

**Causes** :
- Cache n'est jamais accédé (bug dans _recomputeDerivedWithCache?)
- Critères trop spécifiques (chaque requête unique)

**Fix** :
1. Vérifier que `fetchExistingJourney()` est appelé
2. Ajouter logs `debugPrint('Criteria hash: $hash')` 
3. Vérifier Firestore: `/toolbox_journey_index` a docs?

### Hit rate > 100% (bug)

**Cause** : Double comptage (hit enregistré 2x)

**Fix** :
- Vérifier que `recordCacheHit` n'est appelé qu'une fois
- Reset metrics: `monitoring.reset()`

### Temps moyen = 0ms

**Cause** : Pas d'accès au cache encore

**Fix** :
- Effectuer quelques requêtes
- Attendre calcul de la moyenne

---

## Firestore Rules pour analytics

```
match /cache_analytics/{document=**} {
  allow read: if request.auth != null && hasRole('admin');
  allow create: if request.auth != null;  // Tout le monde peut écrire ses metrics
}
```

---

## Next steps

1. **Deploy & Monitor** (1-2 semaines)
   - Pousser en prod
   - Observer hit rate réel
   
2. **Analyze results**
   - Hit rate >= 40%? Keep
   - Hit rate < 40%? Optimize criteria

3. **Optimize**
   - Ajouter critères si needed
   - Test A/B matching strategies

---

**Dernière mise à jour**: 5 jan 2026
