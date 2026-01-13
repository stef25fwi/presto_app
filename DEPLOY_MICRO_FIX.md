# 🚀 Déploiement Rapide - Correction Microphone

## ✅ Scripts NPM Disponibles

```bash
# Voir tous les scripts disponibles
npm run

# Déployer sur GitHub Pages
npm run deploy:web

# Déployer sur Firebase Hosting
npm run deploy:firebase

# Build uniquement
npm run build:web
```

## 📦 Déploiement Complet (Étape par Étape)

### Option A : GitHub Pages (Recommandé)

```bash
cd /workspaces/presto_app

# 1. Build
flutter clean
flutter pub get
flutter build web --release --base-href "/presto_app/"

# 2. Deploy
npm run deploy:web
```

**URL finale** : https://stef25fwi.github.io/presto_app/

### Option B : Firebase Hosting

```bash
cd /workspaces/presto_app

# 1. Build
flutter clean
flutter pub get
flutter build web --release

# 2. Deploy
firebase deploy --only hosting
```

**URL finale** : Vérifier dans Firebase Console

### Option C : Manuel (GitHub Pages)

```bash
cd /workspaces/presto_app

# 1. Build
flutter clean
flutter pub get
flutter build web --release --base-href "/presto_app/"

# 2. Copier vers docs/
mkdir -p docs
touch docs/.nojekyll
rm -rf docs/* (sauf .nojekyll)
cp -a build/web/. docs/

# 3. Commit et push
git add docs/
git commit -m "deploy: correction microphone"
git push origin main
```

## 🧪 Test Après Déploiement

1. **Ouvrir le site**
   - GitHub Pages : https://stef25fwi.github.io/presto_app/
   - Firebase : Votre URL Firebase

2. **Connexion**
   - Se connecter avec un compte

3. **Navigation**
   - Cliquer sur "Je publie" (icône ➕ orange)

4. **Test Microphone**
   - Cliquer sur "Décrire mon besoin (IA)" 🎤
   - Autoriser le micro si demandé
   - Parler : "Je cherche un plombier à Fort-de-France"
   - Cliquer pour arrêter

5. **Vérifications**
   - ✅ Message : "Transcription réussie et champs remplis"
   - ✅ Champs remplis automatiquement
   - ✅ Aucune erreur console (F12)

## 🔧 Vérification du Build

```bash
# Vérifier que le build existe
ls -lh build/web/

# Vérifier la taille du build
du -sh build/web/

# Vérifier les fichiers principaux
ls -lh build/web/index.html
ls -lh build/web/main.dart.js

# Vérifier que la correction est appliquée
grep -r "microIaProcessAudio" build/web/main.dart.js
# Devrait trouver des correspondances
```

## 📊 Logs de Débogage

### Console Navigateur (F12)
Recherchez dans la console JavaScript :
```
[Streaming Web] Chunk uploaded: ...
[Streaming Web] Chunk transcribed: "..."
```

### Firebase Functions Logs
```bash
firebase functions:log --only microIaProcessAudio --limit 20
```

Vous devriez voir :
```
[microIaProcessAudio] CALL { uid: "...", storagePath: "stt/..." }
[microIaProcessAudio] DONE { modeUsed: "GOOGLE_ONLY" }
```

## ⚡ Déploiement Express (1 Commande)

```bash
cd /workspaces/presto_app && flutter clean && flutter pub get && npm run deploy:web
```

## 🆘 Dépannage

### Erreur : "Missing script: deploy:web"
**Solution** : Le package.json a été mis à jour. Faire :
```bash
git pull origin main
npm install
```

### Erreur : "flutter: command not found"
**Solution** : Installer Flutter ou utiliser un conteneur avec Flutter

### Erreur : "Permission denied" (deploy_pages.sh)
**Solution** :
```bash
chmod +x scripts/deploy_pages.sh
bash scripts/deploy_pages.sh
```

### Erreur : "You are not on main branch"
**Solution** :
```bash
git checkout main
git pull
npm run deploy:web
```

### Build trop volumineux
**Solution** : Utiliser web-renderer auto
```bash
flutter build web --release --web-renderer auto --base-href "/presto_app/"
```

## 📝 Checklist de Déploiement

Avant de déployer :
- [ ] Code compilé sans erreur : `flutter analyze`
- [ ] Tests passés (si disponibles)
- [ ] Build réussi : `flutter build web --release`
- [ ] Fichier corrigé : `lib/features/micro_ia/micro_ia_service.dart`

Après déploiement :
- [ ] Site accessible (GitHub Pages ou Firebase)
- [ ] Page "Je publie" fonctionne
- [ ] Bouton micro visible
- [ ] Transcription fonctionne
- [ ] Champs se remplissent
- [ ] Aucune erreur console

## 🎯 URLs Importantes

- **Site GitHub Pages** : https://stef25fwi.github.io/presto_app/
- **Repo GitHub** : https://github.com/stef25fwi/presto_app
- **Firebase Console** : https://console.firebase.google.com/

---

**Dernière mise à jour** : 2026-01-13  
**Scripts ajoutés** : `deploy:web`, `deploy:firebase`, `build:web`
