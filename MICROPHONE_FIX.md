# Correction du Micro sur la Page "Je Publie"

## Problème Identifié

Le microphone ne fonctionnait pas sur la page de publication d'annonces. La transcription audio et le remplissage automatique des champs ne s'effectuaient pas.

## Cause Racine

Le service Flutter `MicroIaService` appelait une Cloud Function nommée `transcribeAudio`, mais la fonction Firebase déployée s'appelle `microIaProcessAudio`.

## Fichier Corrigé

### `/lib/features/micro_ia/micro_ia_service.dart`

**Avant :**
```dart
final callable = functions.httpsCallable(
  'transcribeAudio',  // ❌ Mauvais nom
  options: HttpsCallableOptions(
    timeout: streamingMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 60),
  ),
);
```

**Après :**
```dart
final callable = functions.httpsCallable(
  'microIaProcessAudio',  // ✅ Nom correct
  options: HttpsCallableOptions(
    timeout: streamingMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 60),
  ),
);
```

## Architecture du Système de Transcription

### Côté Client (Flutter)

1. **Bouton Micro** : `PremiumAiButton` sur [/lib/main.dart](lib/main.dart#L9176)
2. **Démarrage** : `_startStreamingMic()` en ligne 7520
   - Web : Mode chunking (chunks de 2 secondes)
   - Mobile : Streaming PCM16 16kHz
3. **Service** : `MicroIaService.processAudio()` appelle `microIaProcessAudio`

### Côté Backend (Cloud Functions)

1. **Fonction** : `microIaProcessAudio` dans [/functions/index.js](functions/index.js#L1363)
2. **Pipeline** :
   - Validation et authentification
   - Conversion audio (WEBM → WAV 16kHz mono si nécessaire)
   - Transcription via Google Speech-to-Text ou Whisper
   - Évaluation de la qualité
3. **Modes disponibles** :
   - `GOOGLE_ONLY` : Google STT uniquement
   - `WHISPER_ONLY` : OpenAI Whisper uniquement
   - `HYBRID` : Combinaison des deux

## Flux Complet

```
Utilisateur appuie sur le bouton micro
  ↓
_startStreamingMic() démarre l'enregistrement
  ↓
Chunks audio uploadés vers Firebase Storage (stt/${uid}_${timestamp}.webm)
  ↓
MicroIaService.processAudio(storagePath) appelé
  ↓
Cloud Function microIaProcessAudio :
  - Télécharge l'audio
  - Convertit en WAV 16kHz mono (si nécessaire)
  - Transcrit avec Google STT/Whisper
  - Retourne { text, quality, modeUsed }
  ↓
_transcriptionStream reçoit le texte
  ↓
_applyFastDraftFromTranscript() remplit les champs :
  - Titre (première phrase)
  - Description (texte complet)
  - Code postal (détecté dans le texte)
  - Ville (via recherche ou code postal)
  ↓
_finalizeAiDraftFromTranscript() affine avec OpenAI :
  - Catégorie intelligente
  - Titre optimisé
  - Description structurée
```

## Tests de Validation

### Test 1 : Enregistrement Simple
1. Ouvrir la page "Je publie une offre"
2. Appuyer sur "Décrire mon besoin (IA)"
3. Autoriser l'accès au microphone
4. Parler clairement : "Je cherche quelqu'un pour monter un meuble IKEA à Baie-Mahault"
5. Appuyer à nouveau pour arrêter
6. **Résultat attendu** :
   - Transcription visible
   - Champs remplis automatiquement
   - Message "Transcription réussie et champs remplis"

### Test 2 : Mode Streaming (Web)
1. Sur navigateur web, ouvrir la page de publication
2. Démarrer l'enregistrement
3. Parler pendant 5-10 secondes
4. **Observer** : Transcription partielle qui apparaît progressivement
5. Arrêter l'enregistrement
6. **Résultat attendu** : Champs complétés avec analyse IA finale

### Test 3 : Extraction Intelligente
1. Dicter : "J'ai besoin d'un plombier urgent à Fort-de-France 97200"
2. **Vérifier** :
   - ✅ Titre : "Plombier urgent"
   - ✅ Description : texte complet
   - ✅ Ville : "Fort-de-France"
   - ✅ Code postal : "97200"
   - ✅ Catégorie : "Plomberie" ou équivalent

## Logs de Débogage

### Côté Client
```dart
debugPrint('[Streaming Web] Chunk uploaded: $chunkPath (${chunkBytes.length} bytes)');
debugPrint('[Streaming Web] Chunk transcribed: "$text"');
```

### Côté Serveur
```javascript
console.log("[microIaProcessAudio] CALL", { uid, storagePath, languageCode });
console.log("[microIaProcessAudio] DONE", { modeUsed, score });
```

### Vérification des Logs
```bash
# Logs Firebase Functions
firebase functions:log --only microIaProcessAudio

# Logs Flutter
flutter run --release
# Puis consulter la console
```

## Déploiement

### 1. Redéployer les Functions (si modifiées)
```bash
cd functions
firebase deploy --only functions:microIaProcessAudio
```

### 2. Rebuild l'App Flutter
```bash
flutter clean
flutter pub get
flutter build web --release
```

### 3. Publier sur GitHub Pages
```bash
npm run deploy:web
```

## Dépendances

### Flutter (pubspec.yaml)
- `cloud_functions: ^5.2.0`
- `firebase_storage: ^12.3.6`
- `record: ^5.1.2` (audio mobile)

### Cloud Functions (package.json)
- `@google-cloud/speech: ^6.7.1`
- `openai: ^4.104.0`
- `ffmpeg-static: ^5.2.0`

## Configuration Firebase

### Storage Rules
```javascript
// Chemin : storage.rules
match /stt/{userId}_{timestamp}.{extension} {
  allow write: if request.auth != null && request.auth.uid == userId;
  allow read: if request.auth != null;
}
```

### Remote Config (Micro-IA)
- `microia_mode` : "GOOGLE_ONLY" | "WHISPER_ONLY" | "HYBRID"
- `microia_fallback_enabled` : true
- `microia_quality_threshold` : 0.62
- `microia_ultra_fast_enabled` : false
- `microia_language_code` : "fr-FR"

## Résolution de Problèmes

### Erreur : "Authentication required"
**Solution** : Vérifier que l'utilisateur est connecté avant d'enregistrer

### Erreur : "Audio file not found"
**Solution** : Vérifier les permissions Storage et l'upload du fichier

### Erreur : "Audio trop court"
**Solution** : Parler plus longtemps (minimum 1-2 secondes)

### Pas de transcription
1. Vérifier les logs Firebase : `firebase functions:log`
2. Vérifier le nom de la fonction : doit être `microIaProcessAudio`
3. Vérifier que la fonction est déployée : `firebase functions:list`

### Transcription incorrecte
1. Parler plus clairement et plus fort
2. Réduire le bruit ambiant
3. Activer le mode `ultraFastEnabled: false` pour meilleure qualité

## Statut

✅ **Corrigé** - Le nom de la fonction Cloud a été corrigé dans `MicroIaService`

**Date** : 2026-01-13
**Version** : 1.0.0
**Auteur** : GitHub Copilot
