# 🔍 Comment voir les logs d'authentification Firebase

## ✅ Ce qui a été fait

**Logs détaillés ajoutés dans [lib/profile_page.dart](lib/profile_page.dart) :**
- 🔵 Logs bleus : informations générales
- ✅ Logs verts : succès
- ⚠️ Logs jaunes : avertissements
- ❌ Logs rouges : erreurs

**Méthodes instrumentées :**
1. `_checkGoogleRedirectResult()` - Vérification du retour de redirect Google
2. `_onGoogleSignIn()` - Processus complet de connexion Google

---

## 📺 Voir les logs en temps réel

### Option 1 : Flutter Run (Recommandé pour dev)
```bash
flutter run -d chrome
```

**Dans le terminal VS Code, vous verrez :**
```
🔵 [AUTH] ========================================
🔵 [AUTH] Starting Google Sign-In...
🔵 [AUTH] Current user: null
🔵 [AUTH] Platform: Web
🔵 [AUTH] Auth Domain: presto-app-74abe.firebaseapp.com
🔵 [AUTH] Provider configured with scopes: email, profile
🔵 [AUTH] Using Web flow (Popup with Redirect fallback)
🔵 [AUTH] Attempting popup sign-in...
```

### Option 2 : Console du navigateur (F12)
1. Ouvrir la console : **F12** ou **Ctrl+Shift+I**
2. Onglet **Console**
3. Filtrer par "AUTH" pour voir uniquement les logs d'authentification

### Option 3 : Build + Deploy (Production)
```bash
flutter build web --release
firebase deploy --only hosting
```
Puis ouvrir : https://presto-app-74abe.web.app
- Ouvrir F12 → Console
- Tenter une connexion Google
- Observer les logs

Alternative (Linux/dev container) :
```bash
"$BROWSER" https://presto-app-74abe.web.app
```

---

## 🔍 Interpréter les logs

### ✅ Connexion réussie (popup)
```
🔵 [AUTH] Starting Google Sign-In...
🔵 [AUTH] Platform: Web
🔵 [AUTH] Attempting popup sign-in...
✅ [AUTH] Popup sign-in successful!
✅ [AUTH] User: votre-email@gmail.com
✅ [AUTH] UID: AbCd123XyZ...
🔵 [AUTH] Sign-in flow completed
```
**Action : Rien, tout fonctionne !**

### ⚠️ Popup bloquée → Redirect
```
🔵 [AUTH] Attempting popup sign-in...
⚠️ [AUTH] POPUP BLOCKED or FAILED
🔄 [AUTH] Fallback to redirect...
🔄 [AUTH] Redirect initiated, browser will redirect now
```
**Action : Normal, le navigateur redirige vers Google**

Puis au retour :
```
🔍 [REDIRECT] Checking for redirect result...
✅ [REDIRECT] User returned from Google redirect
✅ [REDIRECT] Email: votre-email@gmail.com
```

### ❌ Erreur : Domaine non autorisé
```
🔵 [AUTH] Attempting popup sign-in...
❌ [AUTH] FirebaseAuthException caught
❌ [AUTH] Code: unauthorized-domain
⚠️ [AUTH] DOMAIN NOT AUTHORIZED!
⚠️ [AUTH] Add this domain in Firebase Console → Authentication → Authorized domains
```
**Action requise :**
1. Copier l'URL actuelle (ex: `https://xyz-5000.app.github.dev`)
2. Aller sur https://console.firebase.google.com/project/presto-app-74abe/authentication/settings
3. Cliquer "Add domain"
4. Coller l'URL (sans le protocole https://)
5. Sauvegarder et attendre 30 secondes
6. Réessayer

### ❌ Erreur : Google Sign-In non activé
```
❌ [AUTH] Code: operation-not-allowed
⚠️ [AUTH] GOOGLE SIGN-IN NOT ENABLED!
```
**Action requise :**
1. Aller sur https://console.firebase.google.com/project/presto-app-74abe/authentication/providers
2. Cliquer sur "Google"
3. Activer le toggle
4. Configurer le Web SDK avec le Client ID
5. Sauvegarder

### ❌ Erreur : Popup fermée par l'utilisateur
```
❌ [AUTH] Code: popup-closed-by-user
ℹ️ [AUTH] User closed the popup
```
**Action : Normal, l'utilisateur a fermé la fenêtre Google. Réessayer.**

---

## 🧪 Scénarios de test

### Test 1 : Connexion popup (idéal)
```bash
# Lancer l'app
flutter run -d chrome

# Dans l'app, cliquer sur "Se connecter avec Google"
# Observer les logs dans le terminal
```

**Résultat attendu :**
- Popup Google s'ouvre
- Sélection du compte
- Popup se ferme
- Message "Connecté avec Google"
- Logs ✅ verts dans le terminal

### Test 2 : Connexion redirect (fallback)
```bash
# Même chose, mais avec bloqueur de popup actif
```

**Résultat attendu :**
- Tentative popup échoue
- Redirection vers google.com
- Retour sur l'app
- Message "Connecté avec Google"
- Logs ✅ verts au retour

### Test 3 : Nouveau domaine non autorisé
```bash
# Tester depuis un nouveau Codespace ou localhost
```

**Résultat attendu :**
- Logs ❌ rouges : "unauthorized-domain"
- Message d'erreur explicite
- Instructions pour ajouter le domaine

---

## 📋 Checklist de debug

Si l'authentification échoue, vérifier dans cet ordre :

1. **[ ] Voir les logs dans le terminal**
   - `flutter run -d chrome`
   - Chercher les lignes avec `[AUTH]`

2. **[ ] Identifier le code d'erreur**
   - `unauthorized-domain` → Ajouter domaine dans Firebase Console
   - `operation-not-allowed` → Activer Google Sign-In dans Firebase
   - `popup-closed-by-user` → L'utilisateur a annulé (normal)
   - `popup-blocked` → Fallback redirect se déclenche (normal)

3. **[ ] Vérifier Firebase Console**
   - Authentication → Sign-in method → Google activé ?
   - Authentication → Settings → Authorized domains contient votre domaine ?

4. **[ ] Vérifier Google Cloud Console**
   - Credentials → Web client OAuth 2.0
   - Authorized JavaScript origins contient vos domaines ?
   - Authorized redirect URIs contient `https://presto-app-74abe.firebaseapp.com/__/auth/handler` ?

5. **[ ] Rebuild et redéployer**
   ```bash
   flutter clean
   flutter build web --release
   firebase deploy --only hosting
   ```

---

## 🚀 Commandes rapides

### Voir les logs en dev
```bash
flutter run -d chrome --verbose
```

### Filtrer les logs AUTH uniquement
```bash
flutter run -d chrome 2>&1 | grep "AUTH"
```

### Test sur le site en production
```bash
# Ouvrir le site
open https://presto-app-74abe.web.app

# Ouvrir la console navigateur (F12)
# Tenter une connexion
# Observer les logs dans Console
```

---

## 💡 Astuce : Logs dans la console navigateur

Les `debugPrint()` Flutter apparaissent aussi dans la console du navigateur (F12).

Pour les filtrer :
1. Ouvrir F12 → Console
2. Dans le champ de filtre, taper : `AUTH`
3. Vous verrez uniquement les logs d'authentification

---

**Logs ajoutés le :** 6 janvier 2026  
**Fichier modifié :** [lib/profile_page.dart](lib/profile_page.dart)  
**Prochaine étape :** Tester avec `flutter run -d chrome` et observer les logs
