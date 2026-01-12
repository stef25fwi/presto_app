# Vérification Configuration Google Sign-In

## ✅ État actuel du code

Le code de connexion Google est **correctement implémenté** dans `lib/main.dart` :
- ✅ Popup avec fallback redirect (ligne 8457-8510)
- ✅ Gestion des erreurs complète
- ✅ Vérification du redirect au chargement de la page (ligne 8370-8391)
- ✅ `setCustomParameters({'prompt': 'select_account'})`

## 🔍 Points à vérifier

### 1. Firebase Console - Authentication

**Lien direct** : https://console.firebase.google.com/project/presto-app-74abe/authentication/providers

#### Actions à faire :
1. **Activer Google Sign-In** :
   - Aller dans Authentication → Sign-in method
   - Activer "Google" si pas déjà fait
   - Vérifier que le statut est "Enabled"

2. **Obtenir le Web Client ID** :
   - Dans la configuration Google, tu verras le **Web Client ID**
   - Format : `151421230024-XXXXX.apps.googleusercontent.com`
   - Copier cette valeur complète

3. **Ajouter les domaines autorisés** :
   - Toujours dans Authentication → Settings → Authorized domains
   - Ajouter :
     - `stef25fwi.github.io` (GitHub Pages)
     - `localhost` (dev local)
     - Ton domaine Codespaces si tu testes depuis Codespaces

### 2. Google Cloud Console - OAuth Credentials

**Lien direct** : https://console.cloud.google.com/apis/credentials?project=presto-app-74abe

#### Actions à faire :
1. **Vérifier les OAuth 2.0 Client IDs** :
   - Tu devrais voir un client Web créé par Firebase
   - Note : Le nom contient souvent "Web client (auto created by Google Service)"

2. **Ajouter les URI autorisés** :
   - Cliquer sur le client Web
   - **Authorized JavaScript origins** :
     - `https://stef25fwi.github.io`
     - `http://localhost`
     - `https://[ton-codespace].github.dev` (si tu testes depuis Codespaces)
   - **Authorized redirect URIs** :
     - `https://stef25fwi.github.io/__/auth/handler`
     - `http://localhost/__/auth/handler`
     - `https://presto-app-74abe.firebaseapp.com/__/auth/handler`

3. **Écran de consentement OAuth** :
   - Aller dans OAuth consent screen
   - Vérifier que le statut n'est pas "Testing" (sinon limité à certains emails)
   - Si "Testing", publier l'application ou ajouter les comptes test

### 3. Mise à jour du code

Une fois que tu as le **vrai Web Client ID** depuis Firebase Console :

#### Fichier : `web/index.html`
```html
<!-- Remplacer la ligne 32 -->
<meta name="google-signin-client_id" content="TON_VRAI_CLIENT_ID.apps.googleusercontent.com">
```

**Note** : Ce meta tag n'est pas strictement nécessaire pour Firebase Auth, mais c'est une bonne pratique.

### 4. Test de la configuration

#### Commandes de vérification :
```bash
# 1. Rebuild l'app web avec la nouvelle config
flutter clean
flutter build web

# 2. Tester localement
flutter run -d chrome

# 3. Déployer sur GitHub Pages
# (copier le contenu de build/web/ vers docs/ si c'est ta config)
```

#### Scénarios de test :
1. **Test Popup** :
   - Cliquer sur "Connexion avec Google"
   - Une popup devrait s'ouvrir
   - Sélectionner un compte Google
   - Vérifier la connexion réussie

2. **Test Redirect** (si popup bloqué) :
   - La page devrait se rediriger vers Google
   - Après connexion, retour automatique à l'app
   - `_checkGoogleRedirectResult()` détecte le retour

3. **Erreurs courantes** :
   - `unauthorized-domain` → Ajouter le domaine dans Firebase Console
   - `operation-not-allowed` → Activer Google dans Authentication
   - `popup-blocked` → Le fallback redirect devrait fonctionner
   - `invalid-oauth-client` → Vérifier le Client ID et les URIs autorisés

## 📋 Checklist de vérification

- [ ] Google Sign-In activé dans Firebase Console
- [ ] Web Client ID copié depuis Firebase Console
- [ ] Domaines autorisés ajoutés dans Firebase (Settings → Authorized domains)
- [ ] JavaScript origins configurés dans Google Cloud Console
- [ ] Redirect URIs configurés dans Google Cloud Console
- [ ] Écran de consentement OAuth publié (ou comptes test ajoutés)
- [ ] `web/index.html` mis à jour avec le vrai Client ID
- [ ] App rebuild et testée localement
- [ ] App déployée et testée en production

## 🔧 Debug

### Logs à surveiller dans la console navigateur :
```
[Google Sign-In] Popup failed, trying redirect: ...
[Google Redirect] Error checking result: ...
```

### Test manuel rapide :
```javascript
// Dans la console du navigateur (F12)
firebase.auth().signInWithPopup(new firebase.auth.GoogleAuthProvider())
  .then(result => console.log('Success:', result))
  .catch(error => console.error('Error:', error));
```

## 📚 Documentation officielle

- Firebase Authentication : https://firebase.google.com/docs/auth/web/google-signin
- Google Cloud OAuth : https://developers.google.com/identity/protocols/oauth2
- FlutterFire : https://firebase.flutter.dev/docs/auth/social#google

## ⚠️ Notes importantes

1. **Sécurité** : Le Client ID Web peut être public (il est exposé dans le HTML)
2. **API Key** : L'API Key Firebase dans `firebase_options.dart` est aussi publique
3. **Protection** : La sécurité vient des règles Firestore/Storage et des domaines autorisés
4. **Production** : Pense à publier l'écran de consentement OAuth pour tous les utilisateurs
