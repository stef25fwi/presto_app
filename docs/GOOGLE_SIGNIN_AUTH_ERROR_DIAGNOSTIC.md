# Diagnostic Google Sign-In - Erreurs INTERNAL_ERROR / AUTH_ERROR

## Symptômes
- `INTERNAL_ERROR` ou `AUTH_ERROR` lors de la connexion Google
- Erreur OAuth2 après popup ou redirect
- Erreur dans `_signInWithGoogle()` à Firebase

## Causes probables

### 1. **Configuration OAuth2 manquante**
Firebase doit créer un client OAuth2 Web pour ton app.

**Checklist Firebase** :
- [ ] Firebase Console → Projet → Authentication
- [ ] Onglet "Sign-in method"
- [ ] Google : **Activé**
- [ ] Client ID public visible (Web SDK configuration)

**Checklist Google Cloud Console** :
- [ ] Google Cloud Console → Credentials
- [ ] Type: "OAuth 2.0 Client ID (Web)"
- [ ] "Authorized JavaScript origins" contient:
  - [ ] `http://localhost:3000` (dev local)
  - [ ] `https://yourapp.web.app` (production)
  - [ ] `https://yourapp.firebaseapp.com` (Firebase hosting)
- [ ] "Authorized redirect URIs" contient:
  - [ ] `https://yourapp.firebaseapp.com/__/auth/handler`
  - [ ] (Firebase gère ceci automatiquement généralement)

### 2. **Domaine non autorisé**
Erreur: `unauthorized-domain`

**Fix** :
```
Firebase Console → Authentication → Settings → Authorized domains
→ Ajouter ton domaine (localhost, Firebase hosting, etc.)
```

### 3. **Google Sign-In désactivé**
Erreur: `operation-not-allowed`

**Fix** :
```
Firebase Console → Authentication → Sign-in method
→ Google : basculer sur "Activé"
```

### 4. **Problème de configuration OAuth dans Firebase**
Erreur: `internal-error` lors du popup

**Cause** : Firebase ne connaît pas ta clé API Google

**Fix** :
1. Ouvrir [Firebase Console](https://console.firebase.google.com)
2. Projet → Paramètres du projet → Onglet "Intégrations"
3. "Google Cloud" → Ouvrir [Google Cloud Console](https://console.cloud.google.com)
4. S'assurer que le projet GCP lié a les APIs activées:
   - [ ] Google Identity Platform API
   - [ ] Google+ API (legacy, optionnel)
5. Vérifier Credentials → OAuth 2.0 Client IDs → Details
   - Copier `Client ID` depuis GCP vers Firebase si nécessaire

### 5. **Problème de CORS / Origin**
Erreur: `invalid-origin` ou popup vide

**Causes** :
- App servie en `http://` mais Google attend `https://`
- Domaine localhost:PORT non autorisé
- Sous-domaine mismatch

**Fix** :
```
Google Cloud → APIs & Services → Credentials
→ OAuth 2.0 Client ID (Web) → Edit
→ "Authorized JavaScript origins"
→ Ajouter:
  - http://localhost:3000 (avec :PORT exact)
  - https://votredomaine.com
```

### 6. **Mauvais Client ID**
Erreur: `invalid-oauth-client`

**Fix** :
Vérifier que le Client ID Web dans Firebase console est correct.

```
Firebase Console → Paramètres du projet → Onglet "Applications"
→ Sélectionner Web → Copier l'objet JSON
→ Vérifier qu'il contient:
{
  "apiKey": "...",
  "authDomain": "yourapp.firebaseapp.com",
  "projectId": "yourapp",
  "storageBucket": "yourapp.appspot.com",
  "messagingSenderId": "...",
  "appId": "1:...:web:..."
}
```

## Vérification rapide

### Test 1 : Console navigateur
```javascript
// Dans DevTools console de ton app web :
firebase.auth().currentUser  // Doit afficher null (pas connecté)
```

### Test 2 : Vérifier la configuration Firebase en mémoire
```dart
// Dans Flutter main.dart :
FirebaseAuth.instance // Doit être initialisé
print(FirebaseAuth.instance.runtimeType)  // Doit afficher FirebaseAuth
```

### Test 3 : Logs Firebase CLI
```bash
firebase deploy --only auth
firebase functions:log  # Voir logs de validation
```

## Débogages dans le code Flutter

Les logs sont affichés avec :
```dart
debugPrint('[Google Sign-In] Message...')  // Visible dans VS Code Debug Console
```

Cherche :
1. `[Google Sign-In] Tentative avec popup...` - popup lancé
2. `[Google Sign-In] Popup réussi` - connexion réussie
3. `[Google Sign-In] Popup échoué: ...` - erreur (note le message)
4. `[Google Sign-In] Bascule vers redirect...` - fallback activé

## Checklist avant de demander du support

- [ ] Firebase Google Sign-In **activé**
- [ ] Client ID Web créé dans GCP
- [ ] `Authorized JavaScript origins` contient ton domaine
- [ ] `Authorized domains` dans Firebase contient ton domaine
- [ ] Pas de Content Security Policy (CSP) trop restrictive
- [ ] Cookies/localStorage pas bloqués
- [ ] Pas en mode incognito (les cookies sont parfois refusés)

## Code de test minimal

```dart
Future<void> testGoogleSignIn() async {
  try {
    final googleProvider = GoogleAuthProvider();
    final result = await FirebaseAuth.instance.signInWithPopup(googleProvider);
    print('✅ Succès: ${result.user?.email}');
  } on FirebaseAuthException catch (e) {
    print('❌ Erreur: ${e.code} - ${e.message}');
  }
}
```

## Contact support Firebase

Si rien ne fonctionne :
1. Copier le code d'erreur complet (ex: `INTERNAL_ERROR`)
2. Copier le message d'erreur Firebase (ex: `invalid-oauth-client`)
3. Signaler le problème avec screenshot + config Firebase

---

**Dernière mise à jour**: 5 jan 2026
