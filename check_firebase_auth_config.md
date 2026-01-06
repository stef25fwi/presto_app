# Vérification Configuration Firebase Authentication

## Problème actuel
- Clic sur "Se connecter avec Google" → page blanche → redirection vers splashscreen
- L'authentification Google ne fonctionne pas correctement

## Configuration actuelle
### Firebase Options (lib/firebase_options.dart)
- **API Key**: AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo
- **Auth Domain**: presto-app-74abe.firebaseapp.com
- **Project ID**: presto-app-74abe
- **App ID**: 1:151421230024:web:8b83d1d11084c5a02b3efd

### Google Web Client ID (web/index.html)
- **Client ID**: 151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com

## Étapes de vérification à effectuer dans Firebase Console

### 1. Vérifier les domaines autorisés
🔗 https://console.firebase.google.com/project/presto-app-74abe/authentication/providers

**Domaines à ajouter dans "Authorized domains" :**
- `presto-app-74abe.web.app` (Firebase Hosting)
- `presto-app-74abe.firebaseapp.com` (domaine par défaut)
- `localhost` (pour dev local)

### 2. Vérifier Google Sign-In Provider
🔗 https://console.firebase.google.com/project/presto-app-74abe/authentication/providers

**Configuration requise :**
- ✅ Google Provider activé
- ✅ Web SDK configuration avec Client ID correct
- ✅ Support email/password activé si utilisé

### 3. Vérifier OAuth Consent Screen
🔗 https://console.cloud.google.com/apis/credentials/consent?project=presto-app-74abe

**Configuration requise :**
- Type: External (pour test) ou Internal
- Domaines autorisés ajoutés
- Scopes: email, profile

### 4. Vérifier OAuth Client ID
🔗 https://console.cloud.google.com/apis/credentials?project=presto-app-74abe

**Authorized JavaScript origins:**
- `https://presto-app-74abe.web.app`
- `https://presto-app-74abe.firebaseapp.com`
- `http://localhost` (pour dev)

**Authorized redirect URIs:**
- `https://presto-app-74abe.web.app/__/auth/handler`
- `https://presto-app-74abe.firebaseapp.com/__/auth/handler`
- `http://localhost/__/auth/handler`

## Modifications code effectuées

### 1. Ajout gestion redirect result dans ProfilePage
```dart
@override
void initState() {
  super.initState();
  // ... existing code ...
  
  // Sur Web, vérifie si l'utilisateur revient d'un redirect Google Sign-In
  if (kIsWeb) {
    _checkGoogleRedirectResult();
  }
}

Future<void> _checkGoogleRedirectResult() async {
  try {
    final result = await _auth.getRedirectResult();
    if (result.user != null) {
      if (!mounted) return;
      showSuccessSnackBar(context, "Connecté avec Google");
    }
  } on FirebaseAuthException catch (e) {
    // Gestion erreurs avec messages explicites
  }
}
```

### 2. Amélioration gestion erreurs dans _onGoogleSignIn
- Messages d'erreur plus explicites
- Distinction popup/redirect
- Gestion codes d'erreur Firebase spécifiques

## Tests à effectuer

1. **Test Popup** (devrait fonctionner si popup autorisé)
   - Cliquer "Se connecter avec Google"
   - Popup s'ouvre
   - Sélectionner compte Google
   - Redirection vers ProfilePage avec utilisateur connecté

2. **Test Redirect** (si popup bloqué)
   - Cliquer "Se connecter avec Google"
   - Redirection vers page Google
   - Sélectionner compte
   - Retour vers presto-app-74abe.web.app
   - Utilisateur connecté

3. **Vérifier console navigateur**
   - Ouvrir DevTools (F12)
   - Onglet Console
   - Chercher erreurs Firebase Auth
   - Noter codes d'erreur spécifiques

## Commandes pour rebuild et redeploy

```bash
flutter build web --release && npx firebase-tools@11.0.0 deploy --only hosting
```

## Debugging supplémentaire

Si le problème persiste, vérifier dans la console navigateur :
- Erreurs CORS
- Erreurs de domaine non autorisé
- Messages Firebase Auth détaillés
