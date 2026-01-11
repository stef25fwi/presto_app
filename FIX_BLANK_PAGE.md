# 🔧 Fix: Page Blanche sur Firebase Hosting

## 🔍 Problème Identifié

**Symptôme:** Page blanche sur https://presto-app-74abe.web.app

**Cause:** Mauvaise configuration du `base href` dans le build web

```html
<!-- ❌ ACTUEL dans build/web/index.html -->
<base href="/presto_app/">

<!-- ✅ REQUIS pour Firebase Hosting -->
<base href="/">
```

---

## 🚀 Solution Rapide

### Commandes à Exécuter:

```bash
cd /workspaces/presto_app

# 1. Nettoyer
flutter clean

# 2. Récupérer dépendances
flutter pub get

# 3. Build avec le BON base-href
flutter build web --release --base-href="/"

# 4. Vérifier le résultat
cat build/web/index.html | grep "base href"
# Doit afficher: <base href="/">

# 5. Redéployer
firebase deploy --only hosting
```

**OU** exécuter le script:
```bash
chmod +x fix_and_redeploy.sh
./fix_and_redeploy.sh
```

---

## 🐛 Problème Secondaire: firebase_storage

Le warning lors du build:
```
firebase_storage ^12.7.0 doesn't match any versions
```

### Fix:

**Option A - Version spécifique:**
```bash
flutter pub remove firebase_storage
flutter pub add firebase_storage:12.3.0
```

**Option B - Upgrade:**
```bash
flutter pub upgrade --major-versions firebase_storage
```

Modifier `pubspec.yaml`:
```yaml
# Avant
firebase_storage: ^12.7.0

# Après (choisir une version disponible)
firebase_storage: ^12.3.0  # ou la dernière stable
```

Puis:
```bash
flutter pub get
flutter build web --release --base-href="/"
firebase deploy --only hosting
```

---

## ✅ Vérification Post-Déploiement

### 1. Vérifier les fichiers déployés:

```bash
# Lister les fichiers dans build/web
ls -la build/web/

# Vérifier index.html
cat build/web/index.html | head -20
```

### 2. Tester l'URL:

```bash
# Ouvrir dans le navigateur
"$BROWSER" https://presto-app-74abe.web.app

# Ou avec curl
curl -I https://presto-app-74abe.web.app
```

### 3. Vérifier les logs Firebase:

```bash
firebase hosting:channel:list
firebase hosting:disable  # Si besoin de désactiver temporairement
```

---

## 🔍 Debug Console Navigateur

Ouvrir https://presto-app-74abe.web.app et:

1. **Ouvrir DevTools:** F12 ou Clic droit > Inspecter
2. **Console:** Chercher les erreurs en rouge
3. **Network:** Vérifier si les fichiers chargent (200 OK)
4. **Application:** Vérifier le Service Worker

**Erreurs courantes:**
- `Failed to load resource: 404` → base-href incorrect
- `Uncaught ReferenceError` → Build incomplet
- `CORS error` → Configuration Firebase

---

## 📋 Checklist Complète

**Avant rebuild:**
- [ ] Supprimer `build/` folder: `flutter clean`
- [ ] Vérifier `pubspec.yaml` (pas d'erreurs de versions)
- [ ] `flutter pub get` sans erreurs

**Build:**
- [ ] `flutter build web --release --base-href="/"`
- [ ] Vérifier `build/web/index.html` contient `<base href="/">`
- [ ] Pas d'erreurs dans le build

**Deploy:**
- [ ] `firebase deploy --only hosting`
- [ ] 160 fichiers uploadés
- [ ] Hosting URL affichée

**Test:**
- [ ] Page s'affiche sur https://presto-app-74abe.web.app
- [ ] Pas d'erreurs dans console navigateur
- [ ] Navigation fonctionne

---

## 🆘 Si Toujours Blanc

### A. Vérifier firebase.json:

```json
{
  "hosting": {
    "public": "build/web",  // ✅ Correct
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

### B. Tester localement:

```bash
# Serveur local
cd build/web
python3 -m http.server 8000

# Ouvrir: http://localhost:8000
```

Si ça marche localement → problème Firebase config
Si ça ne marche pas → problème build Flutter

### C. Mode maintenance:

Temporairement, créer `build/web/index.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Presto - Maintenance</title>
</head>
<body>
  <h1>🔧 Site en maintenance</h1>
  <p>Retour très bientôt...</p>
</body>
</html>
```

Puis redéployer pour tester que Firebase fonctionne.

---

## 📝 Notes Importantes

1. **base-href pour GitHub Pages:** `/presto_app/`
2. **base-href pour Firebase Hosting:** `/`
3. **Toujours vérifier après build:** `cat build/web/index.html | grep base`

---

**Status:** 🔧 Correction en cours  
**ETA:** 5 minutes après rebuild + redeploy
