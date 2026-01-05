# Production Ready Google Sign-In

## Overview

Service `GoogleAuthService` fourni un système centralisé pour:
- **Gestion d'erreurs enrichie** en français
- **Retry automatique** sur erreurs réseau/temporaires  
- **Fallback popup → redirect** sur web
- **Logging détaillé** pour débugage production

## Utilisation dans `_signInWithGoogle()`

### Approche simple (recommandée)

```dart
final _googleAuthService = GoogleAuthService();

Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);
  
  try {
    _googleAuthService.logAttempt('_signInWithGoogle');
    
    // Exécuter la connexion avec retry automatique
    await _signInWithGoogleWithRetry();
    
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

Future<void> _signInWithGoogleWithRetry() async {
  int retryCount = 0;
  
  while (retryCount <= GoogleAuthService.maxRetries) {
    try {
      if (kIsWeb) {
        await _signInWebWithGooglePopup();
      } else {
        await _signInMobileWithGoogle();
      }
      
      // Succès!
      final user = _auth.currentUser;
      _googleAuthService.logSuccess('_signInWithGoogle', user?.email);
      await _trackLogin(authMethod: 'google', isNewUser: true);
      
      if (mounted) {
        showSuccessSnackBar(context, "✓ Connecté avec Google");
      }
      return;
      
    } catch (e) {
      retryCount++;
      _googleAuthService.logError('_signInWithGoogle', e, retryCount: retryCount);
      
      // Vérifier si on doit retry
      if (!_googleAuthService.shouldRetry(e) || retryCount > GoogleAuthService.maxRetries) {
        // Pas de retry ou max atteint
        if (mounted) {
          final msg = _googleAuthService.getErrorMessage(e);
          msg.showIfNotNull((m) => showErrorSnackBar(context, m));
        }
        rethrow;
      }
      
      // Attendre avant retry
      await Future.delayed(GoogleAuthService.retryDelay);
    }
  }
}

Future<void> _signInWebWithGooglePopup() async {
  final googleProvider = GoogleAuthProvider();
  googleProvider.setCustomParameters({
    'prompt': 'select_account',
  });
  googleProvider.addScope('email');
  googleProvider.addScope('profile');
  
  try {
    _googleAuthService.logAttempt('Web popup');
    await _auth.signInWithPopup(googleProvider);
    
  } catch (popupError) {
    // Fallback vers redirect si popup échoue
    if (_googleAuthService.shouldFallbackToRedirect(popupError)) {
      try {
        _googleAuthService.logFallback('popup', 'redirect', 
          reason: popupError.toString());
        await _auth.signInWithRedirect(googleProvider);
        return;
      } catch (redirectError) {
        _googleAuthService.logError('redirect fallback', redirectError);
        rethrow;
      }
    }
    rethrow;
  }
}

Future<void> _signInMobileWithGoogle() async {
  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  // Déconnexion préventive
  try {
    await googleSignIn.signOut();
  } catch (_) {}
  
  _googleAuthService.logAttempt('Mobile sign-in');
  
  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    _googleAuthService.logError('Mobile', Exception('Annulé par utilisateur'));
    return; // Annulation silencieuse
  }
  
  final googleAuth = await googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  
  await _auth.signInWithCredential(credential);
}
```

---

## Messages d'erreur

Tous les messages sont automatiquement localisés en français via `getErrorMessage()`.

### Exemples:

| Code Firebase | Message utilisateur |
|---|---|
| `internal-error` | "❌ Erreur interne Firebase. Vérifie: Firebase Console → Authentication → Google → Configuration OAuth2" |
| `unauthorized-domain` | "❌ Domaine non autorisé. Admin: Ajoute ce domaine dans Firebase Console → Authentication → Authorized domains" |
| `popup-blocked` | "⚠️ Pop-up bloquée. Autorise les pop-ups pour ce site et réessaye." |
| `network-request-failed` | "📡 Erreur réseau. Vérifie ta connexion internet et réessaye." |
| `cancelled` | *(silencieux, pas d'erreur affichée)* |

---

## Retry automatique

Les erreurs suivantes déclenchent un retry automatique (max 2 tentatives):
- `network-request-failed`
- `internal-error`
- `idp-error`
- Autres erreurs temporaires

**Délai entre tentatives**: 2 secondes

---

## Logging en production

### Debug Console affiche:

```
🔄 [Google Auth] _signInWithGoogle...

❌ [Google Auth] _signInWithGoogle [Retry 1/2] @ 2026-01-05T14:30:22
   Error type: FirebaseAuthException
   Code: internal-error
   Message: null

⚠️ [Google Auth] Fallback: popup → redirect
   Raison: internal-error detected

✅ [Google Auth] _signInWithGoogle réussi @ 2026-01-05T14:30:25
   Email: user@example.com
```

### Pour Crashlytics

Ajouter au catch final:
```dart
FirebaseCrashlytics.instance.recordError(e, st);
```

---

## Testing des erreurs

### Test `internal-error` en dev

```dart
// Simuler une erreur Firebase en dev
throw FirebaseAuthException(
  code: 'internal-error',
  message: 'Test error',
);
```

### Test réseau

Désactiver WiFi/réseau mobile → tentative de connexion → vérifier retry automatique

### Test popup bloqué (Web)

Bloquer popups dans navigateur → essayer connexion → vérifier fallback redirect

---

## Intégration Crashlytics

Ajouter au service:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void logError(String method, dynamic error, {int? retryCount}) {
  // ... logs existant ...
  
  // Envoyer à Crashlytics en production
  if (!kDebugMode) {
    FirebaseCrashlytics.instance.recordError(
      error,
      StackTrace.current,
      reason: '$method [Retry: $retryCount]',
      fatal: false,
    );
  }
}
```

---

## Checklist avant production

- [ ] Service `GoogleAuthService` importé
- [ ] Méthode `_signInWithGoogle` utilise le service
- [ ] Logs affichent "Firebase initialized ✓" au démarrage
- [ ] Erreurs `internal-error` montrent message OAuth2
- [ ] Popup bloqué → fallback redirect activé
- [ ] Retry automatique testé (désactiver réseau)
- [ ] Messages d'erreur clairs et actionnables

---

## Support

Si l'erreur persiste:
1. Consulter `GOOGLE_SIGNIN_AUTH_ERROR_DIAGNOSTIC.md`
2. Vérifier les logs Crashlytics
3. Tester en dev avec debug logs activés

---

**Dernière mise à jour**: 5 jan 2026
