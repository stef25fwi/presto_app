# 🔍 Diagnostic: "Se connecter avec Google" ne fonctionne pas

## ❌ Problème identifié

Le bouton **"Se connecter avec Google"** dans la page "Mon compte" ne fonctionne pas.

## 🔎 Causes principales

### 1. ❌ Client ID Web non configuré

**Fichier**: [web/index.html](web/index.html#L33)
```html
<meta name="google-signin-client_id" content="151421230024-xxxxxxxxxx.apps.googleusercontent.com">
```

Le Client ID contient des `xxxxxxxxxx` au lieu du vrai ID.

### 2. ⚠️ Domaines non autorisés

Firebase Console → Authentication → Settings → Authorized domains
- Localhost (pour dev)
- GitHub Pages (pour prod)
- Codespaces URLs

### 3. ⚠️ Google Sign-In pas activé

Firebase Console → Authentication → Sign-in method → Google (Disabled)

## ✅ Solution étape par étape

### Étape 1: Récupérer le Client ID Web

1. Aller sur **Firebase Console**: https://console.firebase.google.com/project/presto-app-74abe
2. **Project Settings** (⚙️) → **General** tab
3. Scroll vers le bas → Section **"Your apps"**
4. Cliquer sur l'app Web (🌐 Web App)
5. Copier le **Web Client ID** (format: `151421230024-xxxxx.apps.googleusercontent.com`)

**OU**

1. Aller sur **Google Cloud Console**: https://console.cloud.google.com/apis/credentials?project=presto-app-74abe
2. Chercher **"OAuth 2.0 Client IDs"**
3. Trouver le client Web (Type: Web application)
4. Copier le **Client ID**

### Étape 2: Mettre à jour web/index.html

Remplacer:
```html
<meta name="google-signin-client_id" content="151421230024-xxxxxxxxxx.apps.googleusercontent.com">
```

Par:
```html
<meta name="google-signin-client_id" content="VOTRE_VRAI_CLIENT_ID.apps.googleusercontent.com">
```

### Étape 3: Activer Google Sign-In dans Firebase

1. Firebase Console → **Authentication**
2. Tab **"Sign-in method"**
3. Cliquer sur **"Google"**
4. Activer le toggle **"Enable"**
5. Vérifier l'email de support (obligatoire)
6. **Save**

### Étape 4: Autoriser les domaines

Firebase Console → Authentication → Settings → Authorized domains

Ajouter:
- ✅ `localhost` (pour développement)
- ✅ `stef25fwi.github.io` (pour GitHub Pages)
- ✅ Votre URL Codespaces (si utilisé)

### Étape 5: Reconstruire l'app Web

```bash
flutter clean
flutter build web
```

## 🧪 Test de connexion

### Test 1: Vérifier la config

```bash
# Voir le Client ID actuel
grep -r "google-signin-client_id" web/
```

### Test 2: Tester en local

```bash
flutter run -d chrome
```

1. Aller sur la page "Mon compte"
2. Cliquer sur "Continuer avec Google"
3. Observer la console DevTools (F12)

### Erreurs communes

**Popup bloqué**
```
popup_blocked_by_browser
```
→ Autoriser les popups OU l'app bascule automatiquement en redirect

**Domaine non autorisé**
```
unauthorized-domain
```
→ Ajouter le domaine dans Firebase Console

**Client ID invalide**
```
invalid-oauth-client
```
→ Vérifier le Client ID dans web/index.html

**Auth non activé**
```
operation-not-allowed
```
→ Activer Google Sign-In dans Firebase Console

## 📊 État actuel

### ✅ Code correctement configuré

- [x] GoogleAuthService intégré ([lib/services/google_auth_service.dart](lib/services/google_auth_service.dart))
- [x] Méthode `_signInWithGoogle()` implémentée ([lib/main.dart](lib/main.dart#L9015))
- [x] Bouton correctement câblé ([lib/main.dart](lib/main.dart#L9535))
- [x] Fallback popup → redirect
- [x] Gestion d'erreurs en français

### ❌ Configuration manquante

- [ ] Client ID Web dans web/index.html
- [ ] Google Sign-In activé dans Firebase Console
- [ ] Domaines autorisés configurés

## 🔧 Configuration Firebase requise

```javascript
// lib/firebase_options.dart ✅
{
  apiKey: "AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo",
  projectId: "presto-app-74abe",
  authDomain: "presto-app-74abe.firebaseapp.com",
  // ...
}
```

```html
<!-- web/index.html ❌ À CORRIGER -->
<meta name="google-signin-client_id" content="151421230024-XXXXX.apps.googleusercontent.com">
```

## 📝 Checklist finale

Avant de tester:

- [ ] Client ID récupéré depuis Firebase Console
- [ ] web/index.html mis à jour avec le vrai Client ID
- [ ] Google Sign-In activé dans Firebase Authentication
- [ ] Domaines autorisés ajoutés (localhost + production)
- [ ] `flutter clean && flutter build web` exécuté
- [ ] Popup autorisés dans le navigateur

## 🎯 Résultat attendu

Après configuration:

1. Clic sur "Continuer avec Google"
2. Popup Google s'ouvre (ou redirect si popup bloqué)
3. Choix du compte Google
4. Retour à l'app avec message "✓ Connecté avec Google"
5. Redirection vers la page profil

## 📚 Documentation

- [Firebase Authentication - Google](https://firebase.google.com/docs/auth/web/google-signin)
- [Google Sign-In for Web](https://developers.google.com/identity/sign-in/web/sign-in)
- [OAuth 2.0 Client IDs](https://console.cloud.google.com/apis/credentials)
