# Correctifs Google Sign-In - Page Mon Compte

## Problème
La connexion avec Google ne fonctionnait pas correctement sur la page "Mon compte" (AccountPage).

## Solutions appliquées

### 1. Ajout de la meta tag Google Sign-In dans index.html
**Fichier**: `web/index.html`

Ajout de la balise meta requise pour l'authentification Google sur Web :
```html
<meta name="google-signin-client_id" content="151421230024-xxxxxxxxxx.apps.googleusercontent.com">
```

**⚠️ ACTION REQUISE**: Remplacer `xxxxxxxxxx` par ton vrai client ID OAuth Web depuis :
- Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration
- Ou Google Cloud Console → APIs & Services → Credentials

### 2. Amélioration du code de connexion Google
**Fichier**: `lib/main.dart` - Méthode `_signInWithGoogle()`

**Améliorations** :
- Ajout de `setCustomParameters({'prompt': 'select_account'})` pour forcer le choix du compte
- Fallback automatique vers `signInWithRedirect` si la popup échoue/est bloquée
- Gestion améliorée des erreurs spécifiques :
  - `popup-blocked` : Pop-up bloqué par le navigateur
  - `cancelled-popup-request` / `cancelled` : Connexion annulée
  - Messages plus clairs pour l'utilisateur
- Ajout de logs de débogage pour faciliter le diagnostic

### 3. Gestion du retour après redirect
**Fichier**: `lib/main.dart` - Méthode `initState()` de `_AccountPageState`

Ajout d'une vérification automatique du résultat du redirect Google au chargement de la page :
```dart
if (kIsWeb) {
  _checkGoogleRedirectResult();
}
```

Cela permet de :
- Détecter si l'utilisateur revient d'un redirect Google Sign-In
- Finaliser automatiquement la connexion
- Afficher un message de succès
- Gérer les erreurs éventuelles

## Configuration Firebase requise

Pour que Google Sign-In fonctionne correctement, assure-toi que :

1. **Google Sign-In est activé** dans Firebase Console :
   - Firebase Console → Authentication → Sign-in method
   - Google : Activé

2. **Le domaine est autorisé** :
   - Firebase Console → Authentication → Settings → Authorized domains
   - Ajoute ton domaine (ex: `stef25fwi.github.io` pour GitHub Pages)

3. **Client ID OAuth Web configuré** :
   - Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration
   - Copie le "Web client ID" et remplace dans `index.html`

## Test

Pour tester la connexion Google :
1. Ouvre la page Mon compte
2. Clique sur "Continuer avec Google"
3. Si popup bloquée → l'app tente automatiquement un redirect
4. Après avoir choisi un compte Google, tu es ramené à l'app connecté

## Codes d'erreur communs

- `unauthorized-domain` : Domaine non autorisé dans Firebase
- `operation-not-allowed` : Google Sign-In non activé dans Firebase
- `popup-blocked` : Pop-up bloqué → redirect automatique activé
- `popup-closed-by-user` / `cancelled` : Utilisateur a fermé la fenêtre
