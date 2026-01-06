# 🔍 Debug: Page blanche + retour au Splash

## ❌ Problème signalé

Quand on clique sur "Se connecter avec Google":
1. Page blanche apparaît
2. Retour au Splash screen
3. Aucun message d'erreur visible

## 🔎 Causes probables

### 1. ❌ **Popup bloqué par le navigateur** (PLUS PROBABLE)
```
- Popup n'apparaît pas
- Fallback redirect ne se déclenche pas correctement
- Exception lancée mais non affichée
```

### 2. ❌ **Client ID Google mal configuré**
```
Erreur: invalid-oauth-client
- Popup bloquée par Firebase
- L'app lance une exception non gérée
```

### 3. ❌ **Domain non autorisé**
```
Erreur: unauthorized-domain
- Navigateur bloque la connexion
- Popup ne s'ouvre pas
```

### 4. ❌ **Google Sign-In non activé**
```
Erreur: operation-not-allowed
- Firebase refuse la requête
- Exception non visible pour l'utilisateur
```

### 5. ⚠️ **Exception non capturée**
```
- rethrow dans un catch mal géré
- État Widget détruit (mounted = false)
- Erreur de navigation
```

---

## ✅ Corrections appliquées

### 1. Gestion améliorée des erreurs

**Avant** (problématique):
```dart
} catch (popupError) {
  if (shouldFallbackToRedirect) {
    try {
      await signInWithRedirect();
      return;
    } catch (e) {
      rethrow;  // ❌ Relance l'erreur sans affichage
    }
  }
  rethrow; // ❌ Relance l'erreur sans affichage
}
```

**Après** (corrigé):
```dart
} catch (popupError) {
  if (shouldFallbackToRedirect) {
    try {
      await signInWithRedirect();
      return;
    } catch (redirectError) {
      // ✅ Affiche le message d'erreur
      final msg = getErrorMessage(redirectError);
      if (msg.isNotEmpty) {
        showErrorSnackBar(context, msg);
      }
      return; // ✅ Pas de rethrow
    }
  }
  
  // ✅ Gère aussi l'erreur popup directement
  final msg = getErrorMessage(popupError);
  if (msg.isNotEmpty) {
    showErrorSnackBar(context, msg);
  }
  return; // ✅ Pas de rethrow
}
```

### 2. Vérification du widget avant setState()

```dart
if (!mounted) return; // ✅ Évite les erreurs si widget détruit
setState(() => _isLoading = false);
```

### 3. Try-catch autour du tracking

```dart
try {
  await _trackLogin(...);
} catch (trackingError) {
  // ✅ Continue même si tracking échoue
}
```

### 4. Stack trace en cas d'erreur

```dart
} catch (e, stackTrace) {
  debugPrint('Stack trace: $stackTrace');
  // ✅ Aide à déboguer
}
```

---

## 🧪 Comment tester maintenant

### Test 1: Vérifier les logs DevTools

1. `flutter run -d chrome`
2. Ouvrir DevTools (F12)
3. Aller dans **Console**
4. Cliquer sur "Se connecter avec Google"
5. Regarder les logs:

```
🔄 [Google Auth] signInWithGoogle...
   Mode Web
🔄 [Google Auth] Popup...
```

Si erreur:
```
❌ [Google Auth] Popup
   Code: operation-not-allowed
   Message: ...
```

### Test 2: Tester le fallback

Si le popup est bloqué:
```
⚠️ [Google Auth] Fallback: Popup → Redirect
   Raison: Popup bloqué ou erreur interne
🔄 [Google Auth] Redirect...
```

### Test 3: Message d'erreur visible

Maintenant, même si une erreur se produit, vous devriez voir:
```
SnackBar: "❌ Domaine non autorisé. Ajoute-le dans Firebase Console."
```

---

## 📋 Vérification Firebase Console

Pour que le bouton fonctionne, vérifier sur:
https://console.firebase.google.com/project/presto-app-74abe/authentication

### ✅ Sign-in method
```
[ ] Google
  [✓] Enable
  [✓] Web SDK Configuration
  [✓] Support email: configured
```

### ✅ Authorized domains
```
[✓] localhost
[✓] stef25fwi.github.io
[✓] localhost:xxxxx (Codespaces)
```

### ✅ OAuth consent screen
```
https://console.cloud.google.com/apis/credentials/consent
[✓] Application name: Prestō
[✓] User support email: configured
[✓] Developer contact info: configured
```

---

## 🔧 Tests à effectuer

### Test A: Popup bloqué?

Autoriser les popups:
1. Chrome → Settings → Privacy → Pop-ups
2. Ajouter: `localhost:xxxxx` à autoriser

### Test B: Client ID invalide?

Vérifier dans web/index.html:
```html
<meta name="google-signin-client_id" 
  content="151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com">
```

Doit commencer par `151421230024-`

### Test C: Domain autorisé?

Si vous voyez cette erreur:
```
unauthorized-domain
```

→ Ajouter le domaine dans Firebase Console

### Test D: Google Sign-In activé?

Si vous voyez:
```
operation-not-allowed
```

→ Activer Google dans Firebase Console → Authentication → Sign-in method

---

## 🎯 Procédure complète de débugage

### 1. Nettoyer l'app
```bash
flutter clean
```

### 2. Reconstruire
```bash
flutter build web
```

### 3. Lancer avec logs
```bash
flutter run -d chrome
```

### 4. Tester
- Ouvrir la page "Mon compte"
- Cliquer "Se connecter avec Google"
- Regarder la console DevTools (F12) pour les logs
- Regarder si un message d'erreur s'affiche

### 5. Si erreur, copier le message

Partager le message d'erreur visible pour identifier le problème

---

## 📊 Checklist finale

- [x] Gestion améliorée des erreurs (sans rethrow)
- [x] Affichage des messages d'erreur en SnackBar
- [x] Vérification du widget (mounted)
- [x] Logging complet avec stack trace
- [x] Fallback popup → redirect
- [x] Try-catch autour du tracking

**Statut**: ✅ **Code corrigé et déployé**

---

## 📝 Prochaines étapes

1. **Tester** avec les corrections
2. **Vérifier** les logs DevTools
3. **Identifier** le message d'erreur exact
4. **Corriger** selon l'erreur:
   - `unauthorized-domain` → Ajouter domaine
   - `operation-not-allowed` → Activer Google
   - `popup-blocked` → Autoriser popups
   - `invalid-oauth-client` → Vérifier Client ID

---

## 🆘 Si problème persiste

**Partager les logs de la console DevTools** (F12 → Console)

Exemple de logs utiles:
```
❌ [Google Auth] Popup [Retry 0/2]
   Error type: FirebaseAuthException
   Code: unauthorized-domain
   Message: Domaine non autorisé...
```

Cela permettra d'identifier exactement le problème! 🚀
