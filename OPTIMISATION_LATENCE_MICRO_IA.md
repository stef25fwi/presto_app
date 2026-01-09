# 🚀 Optimisation Latence Micro IA

## Modifications Appliquées

### 1. **Réduction des Timeouts**

#### Backend (`functions/index.js`)
- **Avant** : `timeoutSeconds: 120` (2 minutes)
- **Après** : `timeoutSeconds: 40` (40 secondes)
- **Gain** : Échec rapide si le service est lent

#### Client (`lib/features/micro_ia/micro_ia_service.dart`)
- **Avant** : `timeout: Duration(seconds: 75)`
- **Après** : `timeout: Duration(seconds: 30)`
- **Gain** : L'utilisateur n'attend pas indéfiniment

### 2. **Timeouts Internes Plus Agressifs**

En mode ultra-rapide (`ultraFastEnabled: true`):

| Provider | Avant | Après | Gain |
|----------|-------|-------|------|
| Google STT | 12s | 8s | -33% |
| Whisper | 20s | 15s | -25% |
| Hybrid | 25s | 20s | -20% |

### 3. **Seuil de Qualité Réduit**

- **Avant** : `threshold: 0.10` (rejette si score < 0.10)
- **Après** : `threshold: 0.05` (plus tolérant)
- **Impact** : Accepte le premier résultat plus rapidement, évite les fallbacks inutiles

### 4. **Désactivation des Word Time Offsets**

```javascript
features: { 
  automaticPunctuation: true,
  enableWordTimeOffsets: false, // ✅ Désactivé pour gagner du temps
}
```

**Impact** : Réduit le temps de traitement Google Speech (~10-15%)

### 5. **Configuration Remote Config**

Assurez-vous que ces paramètres sont configurés dans Firebase Remote Config :

```json
{
  "microia_ultra_fast_enabled": "true",
  "microia_mode": "HYBRID",
  "microia_quality_threshold": "0.05"
}
```

## Déploiement

```bash
# 1. Déployer les functions
cd functions
npm run deploy

# 2. Redémarrer l'app Flutter
flutter clean
flutter run
```

## Tests de Performance

### Test 1 : Audio Court (2-5 secondes)
**Attendu** : Réponse en 3-6 secondes

```dart
// Lancer l'enregistrement
// Parler 3 secondes
// Arrêter
// ⏱️ Chronométrer jusqu'à l'affichage du texte
```

### Test 2 : Audio Moyen (5-10 secondes)
**Attendu** : Réponse en 6-12 secondes

### Test 3 : Audio Long (10-20 secondes)
**Attendu** : Réponse en 12-25 secondes

## Métriques à Observer

### Logs Backend (Firebase Console)

```
[microIaProcessAudio] TRY {
  attemptMode: 'GOOGLE_ONLY',
  score: 0.85,
  reasons: []
}
```

**Indicateurs positifs** :
- ✅ `attemptMode: 'GOOGLE_ONLY'` → Pas de fallback (rapide)
- ✅ `score > 0.70` → Bonne qualité
- ✅ `reasons: []` → Pas de problèmes détectés

**Indicateurs négatifs** :
- ⚠️ Fallback sur `WHISPER_ONLY` → +10-15 secondes
- ⚠️ `score < 0.30` → Qualité faible, risque de nouveau try
- ⚠️ `timeout:google_stt` → Le timeout a été atteint

## Optimisations Futures Possibles

### 1. **Streaming Audio (WebSocket)**
Au lieu d'uploader tout le fichier puis traiter :
- Stream en temps réel pendant l'enregistrement
- Résultats partiels affichés immédiatement
- **Gain potentiel** : 40-60% de latence en moins

### 2. **Compression Audio Aggressive**
- Réduire le bitrate (16 kHz → 8 kHz pour la voix)
- Utiliser Opus codec (plus compact que WAV)
- **Gain potentiel** : 30-50% de bande passante

### 3. **Caching Côté Client**
- Si l'utilisateur dit souvent les mêmes choses
- Cache local des transcriptions récentes
- **Gain potentiel** : Réponse instantanée pour les phrases répétées

### 4. **Edge Functions (Cloudflare Workers)**
- Déployer une version ultra-légère en edge
- Plus proche géographiquement de l'utilisateur
- **Gain potentiel** : 200-500ms de latency network

### 5. **Modèle On-Device**
- ML Kit Speech Recognition sur l'appareil
- Pas de réseau nécessaire
- **Gain potentiel** : Réponse en < 1 seconde

## Troubleshooting

### "Toujours aussi lent après déploiement"

1. **Vérifier que les functions sont bien déployées** :
```bash
firebase functions:log --only microIaProcessAudio
```

2. **Forcer le refresh du cache Remote Config** :
```bash
# Dans Firebase Console → Remote Config → Publish changes
```

3. **Vider le cache de l'app Flutter** :
```bash
flutter clean
flutter run --release
```

4. **Tester la latence réseau** :
```dart
final start = DateTime.now();
await MicroIaService.processAudio(storagePath: path);
final duration = DateTime.now().difference(start);
print('⏱️ Latence totale : ${duration.inSeconds}s');
```

### "Erreur 'deadline-exceeded'"

→ Le timeout de 40s n'est pas suffisant pour votre audio
→ Solutions :
1. Limiter la durée d'enregistrement à 10-15 secondes max
2. Compresser l'audio avant upload
3. Augmenter le timeout à 60s (compromis)

### "Qualité de transcription dégradée"

→ Le seuil de 0.05 accepte des résultats de mauvaise qualité
→ Solutions :
1. Remonter le seuil à 0.10-0.15
2. Améliorer la qualité audio (réduction bruit)
3. Utiliser un meilleur microphone

## Résultats Attendus

| Scénario | Avant | Après | Amélioration |
|----------|-------|-------|--------------|
| Audio 3s | 8-12s | 4-6s | **-50%** |
| Audio 5s | 12-18s | 6-10s | **-45%** |
| Audio 10s | 20-30s | 12-18s | **-40%** |
| Audio 15s | 30-45s | 18-25s | **-44%** |

**Latence cible finale : 3-8 secondes pour un audio de 5 secondes** ✅
