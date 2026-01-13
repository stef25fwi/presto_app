# Test Rapide : Correction du Microphone

## ✅ Correction Appliquée

Le nom de la Cloud Function a été corrigé dans le service MicroIA :
- **Avant** : `transcribeAudio` (❌ n'existe pas)
- **Après** : `microIaProcessAudio` (✅ fonction déployée)

## 🧪 Test en 3 Minutes

### 1. Rebuild l'Application (Web)
```bash
cd /workspaces/presto_app
flutter clean
flutter pub get
flutter build web --release
```

### 2. Déployer sur GitHub Pages
```bash
# Option 1 : Script automatique (recommandé)
npm run deploy:web

# Option 2 : Firebase Hosting
npm run deploy:firebase

# Option 3 : Manuel
bash scripts/deploy_pages.sh
```

### 3. Tester sur le Site

#### Sur **https://stef25fwi.github.io** :

1. **Connexion**
   - Connectez-vous à votre compte

2. **Navigation**
   - Cliquez sur "Je publie" (icône ➕ orange)

3. **Test du Microphone**
   - Cliquez sur le bouton "Décrire mon besoin (IA)" 🎤
   - Autorisez l'accès au microphone si demandé
   - Parlez clairement pendant 3-5 secondes
   - Exemple : "Je cherche un plombier pour réparer un robinet à Fort-de-France"
   - Cliquez à nouveau pour arrêter

4. **Vérifications**
   ✅ Un message "Transcription réussie et champs remplis" apparaît
   ✅ Le champ **Titre** est rempli automatiquement
   ✅ Le champ **Description** contient votre texte
   ✅ La **Ville** est détectée (si mentionnée)
   ✅ Le **Code postal** est détecté (si mentionné)
   ✅ La **Catégorie** est suggérée par l'IA

## 🔍 Vérification des Logs

### Console DevTools (F12)
```javascript
// Recherchez dans la console :
[Streaming Web] Chunk uploaded: ...
[Streaming Web] Chunk transcribed: "..."
```

### Firebase Functions Logs
```bash
firebase functions:log --only microIaProcessAudio
```

Vous devriez voir :
```
[microIaProcessAudio] CALL { uid: "...", storagePath: "stt/..." }
[microIaProcessAudio] DONE { modeUsed: "GOOGLE_ONLY", score: 0.8 }
```

## ⚠️ Problèmes Courants

### "Permission micro requise"
→ Autorisez l'accès au micro dans les paramètres du navigateur

### "Erreur transcription"
→ Vérifiez les logs Firebase : `firebase functions:log`
→ Assurez-vous d'être connecté

### "Audio trop court"
→ Parlez plus longtemps (minimum 2 secondes)

### Pas de remplissage des champs
→ La transcription fonctionne mais l'IA échoue
→ Vérifiez que OpenAI API Key est configurée dans Firebase

## 📱 Test Mobile (Android/iOS)

```bash
# Android
flutter build apk --release
flutter install

# iOS  
flutter build ios --release
# Puis ouvrir dans Xcode et déployer
```

Le test est identique : aller sur "Je publie" → bouton micro → parler → vérifier les champs.

## 🎯 Résultat Attendu

Après avoir parlé pendant 3-5 secondes, vous devriez voir :

```
✅ Titre: "Plombier pour réparer un robinet"
✅ Description: "Je cherche un plombier pour réparer un robinet à Fort-de-France"
✅ Ville: "Fort-de-France"
✅ Code postal: "97200"
✅ Catégorie: "Plomberie" (suggérée par IA)
```

## 🚀 Déploiement Complet

```bash
# 1. Clean & Build
flutter clean
flutter pub get

# 2. Build Web
flutter build web --release

# 3. Deploy (choisir une option)
# Option A : GitHub Pages (recommandé)
npm run deploy:web

# Option B : Firebase Hosting
npm run deploy:firebase

# Option C : Script manuel
bash scripts/deploy_pages.sh

# 4. Vérifier
# GitHub Pages : https://stef25fwi.github.io/presto_app/
# Firebase Hosting : votre URL Firebase
```

## ✅ Checklist de Validation

- [ ] Le bouton microphone apparaît sur la page "Je publie"
- [ ] Cliquer sur le bouton démarre l'enregistrement (animation)
- [ ] La transcription s'affiche pendant l'enregistrement
- [ ] Les champs se remplissent automatiquement
- [ ] Un message de succès apparaît
- [ ] Aucune erreur dans la console DevTools
- [ ] Aucune erreur dans Firebase Functions logs

## 📊 Monitoring

### Remote Config (Firebase Console)
Vérifiez les paramètres Micro-IA :
- `microia_mode` : "GOOGLE_ONLY" (rapide) ou "HYBRID" (précis)
- `microia_ultra_fast_enabled` : false (qualité) ou true (vitesse)

### Storage Rules
Vérifiez que l'upload fonctionne :
Firebase Console → Storage → `stt/` doit contenir les fichiers audio

## 🔧 Fichier Modifié

**Fichier unique** : `/lib/features/micro_ia/micro_ia_service.dart`

**Ligne 14** : 
```dart
'microIaProcessAudio',  // ✅ Corrigé (était: transcribeAudio)
```

---

**Date de correction** : 2026-01-13  
**Statut** : ✅ Prêt pour test
