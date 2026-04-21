# 🎤 Audit et Optimisation - Pipeline Audio IA pour Annonces

**Date**: 21 avril 2026  
**Objectif**: Analyser et optimiser le pipeline audio pour la rapidité et la précision en français

---

## 📊 État Actuel du Pipeline Audio

### ✅ Architecture Implémentée

```
┌─────────────────────────────────────────────────────────────┐
│                   Publication Annonce (UI)                   │
│                    publish_offer_page.dart                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
   (Enregistrement)              (Analyse)
        │                             │
    record()    ──────────────►   stopMic()
        │                             │
        └──────────────┬──────────────┘
                       │
        ┌──────────────▼──────────────┐
        │    MicroIaService            │
        │  - Authentication            │
        │  - Token Management          │
        │  - Retry Logic               │
        └──────────────┬──────────────┘
                       │
        ┌──────────────▼──────────────┐
        │  Firebase Cloud Functions    │
        │  microIaProcessAudio()       │
        │                             │
        │ Étapes:                     │
        │ 1. Upload Audio             │
        │ 2. Transcribe (Whisper)     │
        │ 3. Extract Fields (GPT-4)   │
        │ 4. Map Results              │
        └──────────────┬──────────────┘
                       │
        ┌──────────────▼──────────────┐
        │   ListingAiMapper            │
        │  - Parse Response            │
        │  - Map to Draft              │
        │  - Compose Description       │
        └──────────────┬──────────────┘
                       │
        ┌──────────────▼──────────────┐
        │   UI Update & Display        │
        │  - Fill Form Fields          │
        │  - Show Results              │
        └──────────────────────────────┘
```

### 📦 Services Clés

| Service | Fichier | Statut | Fonction |
|---------|---------|--------|----------|
| **MicroIaService** | `lib/features/micro_ia/micro_ia_service.dart` | ✅ | Orchestration, auth, retry |
| **ListingAudioAiService** | `lib/services/ai/listing_audio_ai_service.dart` | ✅ | Upload, transcription, extraction |
| **ListingAiMapper** | `lib/services/ai/listing_ai_mapper.dart` | ✅ | Parsing, mapping résultats |
| **AiOfferService** | `lib/features/publish_offer/ai_offer_service.dart` | ✅ | Génération brouillon texte |
| **PremiumAiButton** | `lib/widgets/premium_ai_button.dart` | ✅ | UI du bouton |

---

## ⏱️ Analyse de Performance

### Timing Actuel (Estimé)

```
┌─────────────────────────────────────────────────────────────┐
│ Étape                        │ Durée      │ Position       │
├──────────────────────────────┼────────────┼────────────────┤
│ 1. Enregistrement audio      │ Variable   │ Utilisateur    │
│    (utilisateur parle)       │ (5-30s)    │                │
├──────────────────────────────┼────────────┼────────────────┤
│ 2. Upload vers Storage       │ 2-5s       │ Firebase       │
│    (réseau)                  │            │ Storage        │
├──────────────────────────────┼────────────┼────────────────┤
│ 3. Transcription (Whisper)   │ 3-8s       │ Cloud          │
│    FR en optimisé            │            │ Functions      │
├──────────────────────────────┼────────────┼────────────────┤
│ 4. Extraction Champs (GPT-4) │ 4-10s      │ Cloud          │
│    JSON structuré            │            │ Functions      │
├──────────────────────────────┼────────────┼────────────────┤
│ 5. Mapping & UI Update       │ 0.5-1s     │ Client         │
│    (résultats affichés)      │            │                │
├──────────────────────────────┼────────────┼────────────────┤
│ ✅ TOTAL                     │ 9-24s      │                │
└─────────────────────────────────────────────────────────────┘
```

### Cibles Idéales
```
Performance:
  ✅ Total < 15 secondes (utilisateur normal)
  ✅ Total < 10 secondes (avec optimisations)
  ✅ Affichage partiels pendant l'analyse
  ✅ Retry automatique en cas d'erreur
```

---

## 🔍 Points Forts Actuels

### ✅ 1. Combinaison STT + Draft
```dart
// mic_ia_service.dart:275-281
final res = await retry(
  () => callable.call(<String, dynamic>{
    'storagePath': storagePath,
    if (generateDraft) 'generateDraft': true,  // ← Single round-trip!
    if (generateDraft && draftCity != null) 'draftCity': draftCity,
    ...
```
**Avantage**: 1 appel serveur au lieu de 2 → Économise 1-2s

### ✅ 2. Retry Intelligent
```dart
// micro_ia_service.dart:274-301
maxAttempts: 3,
retryIf: (e) {
  if (e is TimeoutException) return true;
  if (e is FirebaseFunctionsException) {
    return e.code == 'unavailable' ||
           e.code == 'deadline-exceeded' ||
           e.code == 'internal' ||
           e.code == 'resource-exhausted';
  }
  return false;
},
```
**Avantage**: Gère les défaillances réseau automatiquement

### ✅ 3. Token Préemptif
```dart
// micro_ia_service.dart:52-61
static const Duration _kTokenPreemptiveRefreshAge = Duration(minutes: 50);

static bool _shouldForceTokenRefresh() {
  if (_lastForcedTokenRefresh == null) return true;
  return DateTime.now().difference(_lastForcedTokenRefresh!) >
      _kTokenPreemptiveRefreshAge;
}
```
**Avantage**: Évite les erreurs `unauthenticated` lors de l'appel serveur

### ✅ 4. Gestion d'Erreurs en Français
```dart
// micro_ia_service.dart:88-91
throw const MicroIaClientAuthException(
  code: 'auth-missing',
  message: 'Connecte-toi pour utiliser la dictée IA.',
);
```
**Avantage**: Messages clairs pour l'utilisateur

### ✅ 5. Logs Détaillés
```dart
// micro_ia_service.dart:63-65
static void _log(String stage, String message) {
  debugPrint('[MICIA][$stage] $message');
}
```
**Avantage**: Débogage facile via console

---

## ⚡ Optimisations Recommandées

### 1️⃣ Streaming Audio (Réduit la latence)
**Actuellement**: Upload complet → Transcription  
**Optimisation**: Upload par chunks pendant l'enregistrement

```dart
// À implémenter dans web_audio_recorder.dart
Future<void> streamAudioChunk(Uint8List chunk) async {
  await ListingAudioAiService.uploadAudioBytes(
    ownerUid: uid,
    audioBytes: chunk,
    contentType: 'audio/webm',
    extension: '.webm',
    storagePrefix: 'stt_streaming',  // ← Chunks en parallèle
  );
}
```

**Gain**: Économise 1-2 secondes (upload avant la fin de l'enregistrement)

### 2️⃣ Transcription Parallèle
**Actuellement**: Upload → Transcription → Extraction  
**Optimisation**: Transcription commence dès le 1er chunk

```dart
// Pseudo-code
1. Utilisateur parle
2. Chunks uploadés en streaming
3. Transcription commence sur les chunks reçus
4. À la fin: Extraction champs sur transcription complète

Gain: Économise 2-4 secondes
```

### 3️⃣ Caching du Token
**Actuellement**: Refresh toutes les 50 minutes  
**Optimisation**: Cache plus agressif + Refresh on-demand

```dart
// micro_ia_service.dart - Amélioration
static const Duration _kTokenCacheAge = Duration(minutes: 30);

// Avant chaque appel, vérifier et rafraîchir si nécessaire
final idToken = await _getCachedOrRefreshToken(maxAge: _kTokenCacheAge);
```

**Gain**: Réduit les appels de refresh inutiles

### 4️⃣ UI Feedback Progressif
**Actuellement**: Tout à la fin  
**Optimisation**: Affichage des résultats progressifs

```dart
// publish_offer_page.dart - À ajouter
class ProgressiveResults {
  final String? transcription;     // Après STT
  final String? partialTitle;       // Partiellement extrait
  final String? partialDescription; // Pendant l'analyse
  final OfferDraft? finalDraft;    // Complet
}
```

**Gain**: Perception d'une meilleure rapidité

### 5️⃣ Optimisation Modèle Whisper
**Actuellement**: Modèle standard  
**Optimisation**: Modèle optimisé pour le français

```dart
// Dans la fonction Cloud Functions microIaProcessAudio
const WHISPER_MODEL = 'whisper-1';
const LANGUAGE_CODE = 'fr';  // Force explicitement le français

transcription = await openai.audio.transcriptions.create(
  model: WHISPER_MODEL,
  file: audioFile,
  language: LANGUAGE_CODE,  // ← Améliore la précision FR
  prompt: 'Description d'une offre de service en français',  // ← Context
);
```

**Gain**: Meilleure précision, reconnaissance de vocabulaire français spécialisé

### 6️⃣ Extraction Champs Optimisée
**Actuellement**: Extraction générique  
**Optimisation**: Few-shot learning avec exemples français

```dart
// Dans GPT-4 prompt
const SYSTEM_PROMPT = '''
Tu es un expert en extraction d'informations pour des annonces de service.
Extrais les informations suivantes du texte:
- Titre: 2-10 mots, descriptif
- Catégorie: Parmi [Jardinage, Peinture, Aide à domicile, ...]
- Budget: Format {"type": "horaire|fixe", "min": X, "max": Y, "currency": "EUR"}
- Compétences requises: Liste de 3-5 compétences
- ...

EXEMPLES:
1. "Je cherche quelqu'un pour repeindre ma cuisine"
   {"title": "Peinture cuisine", "category": "Peinture", ...}
2. ...
''';
```

**Gain**: Meilleure extraction structurée

---

## 🧪 Tests de Performance

### Test 1: Mesurer la Latence
```bash
# Ajouter dans publish_offer_page.dart
final startTime = DateTime.now();

final result = await MicroIaService.processAudio(
  storagePath: storagePath,
  generateDraft: true,
  draftCity: _selectedCity,
  draftCategory: _selectedCategory,
);

final totalDuration = DateTime.now().difference(startTime);
print('Total: ${totalDuration.inSeconds}s');
```

### Test 2: Précision
Tester avec différents accents et vocabulaires français:
- ✅ Accent parisien
- ✅ Accent québécois
- ✅ Vocabulaire technique (plomberie, électricité, etc.)
- ✅ Chiffres et budgets
- ✅ Adresses et codes postaux

### Test 3: Charge Serveur
- Tester avec 10+ utilisateurs simultanés
- Vérifier les timeouts (75s par défaut)
- Monitorer la mémoire Cloud Functions

---

## 📈 Monitoring et Metrics

### Ajouter dans Firestore
```dart
class PerformanceMetric {
  final String userId;
  final DateTime timestamp;
  final int audioDurationMs;
  final int uploadDurationMs;
  final int transcriptionDurationMs;
  final int extractionDurationMs;
  final int totalDurationMs;
  final bool success;
  final String? errorCode;
  final double? wordAccuracy;
}
```

### Dashboard Firebase Analytics
```
- Taux de succès: Nombre appels réussis / Total
- Latence moyenne: Durée moyenne totale
- P95 latency: 95e percentile
- Erreurs: Distribution des codes d'erreur
- Précision: % de champs correctement extraits
```

---

## 🎯 Checklist d'Optimisation

### Phase 1: Monitoring (Immédiat)
```
☐ Ajouter logging de performance détaillé
☐ Ajouter Firebase Analytics pour les durées
☐ Ajouter Crashlytics pour les erreurs
☐ Créer dashboard de monitoring
```

### Phase 2: Optimisations Rapides (1-2 semaines)
```
☐ Optimiser prompt GPT-4 pour français
☐ Améliorer caching token
☐ Ajouter UI feedback progressif
☐ Tester avec plusieurs accents français
```

### Phase 3: Optimisations Avancées (2-4 semaines)
```
☐ Implémenter streaming audio (chunks)
☐ Paralléliser transcription et extraction
☐ Few-shot learning pour extraction
☐ Optimiser timeout (réduire de 75s si possible)
```

---

## 🚀 Roadmap Recommandée

**Semaine 1-2**:
1. ✅ Ajouter monitoring de performance
2. ✅ Optimiser prompts pour français
3. ✅ Tester avec différents accents

**Semaine 3-4**:
1. ✅ Implémenter UI progressif
2. ✅ Tester et optimiser latence

**Semaine 5-6**:
1. ✅ Streaming audio (si gain significatif)
2. ✅ Few-shot learning
3. ✅ Optimiser Cloud Functions

---

## ✅ Checklist Actuelle

```
Code:
  ✅ MicroIaService: Complet et robuste
  ✅ Retry logic: 3 tentatives
  ✅ Token management: Préemptif
  ✅ Error handling: FR + Messages clairs
  ✅ Logging: Détaillé

UI:
  ✅ Bouton PremiumAiButton: Beau et fonctionnel
  ✅ Indicateurs "Enregistrement en cours"
  ✅ Indicateurs "Analyse en cours"
  ✅ Messages de succès/erreur
  ✅ Gestion des états de chargement

Performance:
  ⚠️ Latence totale: 9-24s (objectif: <10s)
  ⚠️ Pas de streaming audio
  ⚠️ Pas de feedback progressif
  ✅ Retry automatique
  ✅ Token management
```

---

## 🎯 Résumé

**État**: ✅ **Fonctionnel et Robuste**
- Le pipeline audio est correctement implémenté
- Gestion d'erreurs complète
- Retry automatique
- UX claire

**Optimisations à Faire**: 
- Réduire de 15s → 10s total
- Améliorer feedback utilisateur
- Tester précision français

**Priorité**: 🟡 **Moyen**
- Fonctionne actuellement
- Optimisations pour expérience utilisateur
- Pas d'urgence critique

---

**Dernière mise à jour**: 21 avril 2026
