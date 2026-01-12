# 🔍 Debug Page Blanche - Guide Complet

## ✅ Ce qui a été fait

1. ✅ Correction firebase_storage (12.7.0 → 12.3.0)
2. ✅ Build avec base-href correct (`<base href="/">`
3. ✅ Déploiement Firebase réussi (Exit Code: 0)

## 🧪 Tests à Effectuer MAINTENANT

### Test 1: Page de Test Firebase

```bash
# Exécuter le script de diagnostic
chmod +x diagnose_blank_page.sh
./diagnose_blank_page.sh
```

Puis ouvrir: **https://presto-app-74abe.web.app/test.html**

**Résultat attendu:** Page violette avec "✅ Firebase OK"

- ✅ **Si visible** → Firebase fonctionne, problème dans l'app Flutter
- ❌ **Si blanc** → Problème de déploiement/cache Firebase

---

### Test 2: Console Navigateur

Ouvrir: **https://presto-app-74abe.web.app**

1. **Appuyer sur F12** (Ouvrir DevTools)
2. **Onglet Console**
3. **Noter TOUTES les erreurs en rouge**

#### Erreurs courantes et solutions:

**❌ `Failed to load resource: flutter.js 404`**
```bash
# Solution: Rebuild complet
chmod +x full_rebuild_deploy.sh
./full_rebuild_deploy.sh
```

**❌ `Uncaught ReferenceError: _flutter is not defined`**
```bash
# Solution: Problème d'ordre de chargement des scripts
# Modifier build/web/index.html si nécessaire
```

**❌ `FirebaseError: Firebase: No Firebase App '[DEFAULT]' has been created`**
```bash
# Solution: Problème d'initialisation Firebase
# Vérifier web/index.html contient les configs Firebase
```

**❌ `CORS policy: No 'Access-Control-Allow-Origin'`**
```json
// Solution: Ajouter dans firebase.json
"hosting": {
  "headers": [{
    "source": "**",
    "headers": [{
      "key": "Access-Control-Allow-Origin",
      "value": "*"
    }]
  }]
}
```

**❌ Aucune erreur mais page blanche**
- Problème: L'app Flutter charge mais écran blanc
- Cause possible: Erreur dans le code de démarrage (SplashScreen, HomePage)
- Solution: Vérifier les logs Firebase Crashlytics

---

### Test 3: Cache Navigateur

**Vider COMPLETEMENT le cache:**

**Chrome/Edge:**
```
1. Ctrl+Shift+Delete
2. Cocher "Images et fichiers en cache"
3. "Depuis le début"
4. Effacer les données
5. FERMER et ROUVRIR le navigateur
```

**Firefox:**
```
1. Ctrl+Shift+Delete
2. "Cache"
3. "Tout"
4. Effacer maintenant
```

**Safari:**
```
1. Cmd+Option+E
2. Safari > Préférences > Avancées
3. "Vider les caches"
```

---

### Test 4: Navigation Privée

Ouvrir en **mode incognito/privé:**
- Chrome: Ctrl+Shift+N
- Firefox: Ctrl+Shift+P
- Safari: Cmd+Shift+N

Aller sur: https://presto-app-74abe.web.app

Si ça fonctionne en privé → Problème de cache
Si blanc aussi → Problème de build/config

---

## 🛠️ Solutions par Ordre de Probabilité

### Solution 1: Rebuild Complet (80% de chances)

```bash
chmod +x full_rebuild_deploy.sh
./full_rebuild_deploy.sh
```

Ce script va:
- Nettoyer tout (flutter clean + rm -rf build/)
- Rebuild avec --web-renderer auto
- Ajouter une page de test
- Redéployer

### Solution 2: Changer le Renderer (15% de chances)

```bash
# Essayer avec canvaskit
flutter build web --release --base-href="/" --web-renderer canvaskit
firebase deploy --only hosting

# Ou essayer avec html
flutter build web --release --base-href="/" --web-renderer html
firebase deploy --only hosting
```

### Solution 3: Vérifier Firebase Config Web (5% de chances)

Vérifier que `web/index.html` contient la config Firebase:

```html
<script>
  var firebaseConfig = {
    apiKey: "...",
    authDomain: "presto-app-74abe.firebaseapp.com",
    projectId: "presto-app-74abe",
    // ...
  };
  firebase.initializeApp(firebaseConfig);
</script>
```

---

## 📊 Checklist de Diagnostic

Remplir cette checklist:

- [ ] Test 1: /test.html s'affiche
- [ ] Test 2: Console sans erreurs
- [ ] Test 3: Cache vidé
- [ ] Test 4: Navigation privée testée
- [ ] Rebuild complet effectué
- [ ] Autres renderers testés

---

## 🆘 Si Toujours Blanc Après Tout

**Collecter ces informations:**

1. **URL exacte testée:**
2. **Navigateur + Version:**
3. **Erreurs console (copier/coller):**
4. **Résultat /test.html:**
5. **Exit code du build:**
6. **Taille de main.dart.js:**

```bash
# Pour obtenir la taille
ls -lh build/web/main.dart.js
```

---

## 🎯 Action Immédiate

**Exécutez maintenant:**

```bash
cd /workspaces/presto_app
chmod +x full_rebuild_deploy.sh
./full_rebuild_deploy.sh
```

Puis testez:
1. https://presto-app-74abe.web.app/test.html
2. https://presto-app-74abe.web.app (F12 → Console)

**Partagez les résultats des tests !**
