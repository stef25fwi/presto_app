# 🚨 Guide de résolution - Problème d'authentification Firebase

## 🔍 Diagnostic rapide en 3 étapes

### Étape 1 : Tester la page de diagnostic
```bash
# IMPORTANT: ne pas ouvrir en file:// (les imports ES modules Firebase peuvent échouer)
# Servir la page via HTTP, puis ouvrir l'URL.

python3 -m http.server 8000

# Dans un autre terminal:
"$BROWSER" http://localhost:8000/test_firebase_connection.html
```

**Cliquer sur les boutons de test dans l'ordre :**
1. Test Initialisation Firebase
2. Test Firebase Auth
3. Test Firestore
4. Test Google Sign-In (Popup)

**Analyser les résultats :**
- ✅ Tous verts → Le problème vient d'ailleurs (voir Étape 3)
- ❌ Erreur "unauthorized-domain" → Voir **Solution A**
- ❌ Erreur "popup-blocked" → Voir **Solution B**
- ❌ Erreur initialisation → Voir **Solution C**

---

### Étape 2 : Vérifier la configuration automatique
```bash
chmod +x verify_firebase_config.sh
./verify_firebase_config.sh
```

**Si des échecs sont détectés :**
- Lire les messages d'erreur
- Corriger les fichiers manquants
- Relancer le script

---

### Étape 3 : Vérifier Firebase Console

#### A. Vérifier Authentication
1. Aller sur https://console.firebase.google.com/project/presto-app-74abe/authentication
2. Cliquer sur "Sign-in method"
3. **Vérifier Google :**
   - Status : ✅ Activé
   - Web SDK configuration : Web Client ID doit être présent
   - Cliquer sur Google → Modifier → Voir le "Web client ID"

#### B. Vérifier Authorized Domains
1. Dans Authentication → Settings → Authorized domains
2. **Ajouter les domaines suivants si absents :**
   - `localhost` (dev local)
   - `presto-app-74abe.web.app` (production)
   - `presto-app-74abe.firebaseapp.com` (alternative)
   - Votre domaine Codespace si applicable

#### C. Vérifier Google Cloud Console
1. Aller sur https://console.cloud.google.com/apis/credentials?project=presto-app-74abe
2. Trouver le "Web client" OAuth 2.0
3. **Vérifier Authorized JavaScript origins :**
   ```
   https://presto-app-74abe.web.app
   https://presto-app-74abe.firebaseapp.com
   http://localhost
   http://localhost:5000
   ```
4. **Vérifier Authorized redirect URIs :**
   ```
   https://presto-app-74abe.firebaseapp.com/__/auth/handler
   http://localhost/__/auth/handler
   ```

---

## 🔧 Solutions aux problèmes courants

### Solution A : Erreur "unauthorized-domain"

**Problème :** Le domaine depuis lequel vous testez n'est pas autorisé.

**Fix :**
1. Ouvrir Firebase Console → Authentication → Settings → Authorized domains
2. Cliquer "Add domain"
3. Ajouter votre domaine (exemple : `your-codespace-xyz.github.dev`)
4. Sauvegarder
5. Attendre 30 secondes et retester

### Solution B : Erreur "popup-blocked"

**Problème :** Le navigateur bloque la popup Google Sign-In.

**Fix :**
1. Autoriser les popups pour votre site dans le navigateur
2. OU utiliser le bouton "Test Google Sign-In (Redirect)" à la place
3. OU ajouter ce code dans l'app Flutter :
   ```dart
   // Déjà présent dans profile_page.dart lignes 128-132
   catch (popupError) {
     await _auth.signInWithRedirect(provider);
   }
   ```

### Solution C : Erreur d'initialisation Firebase

**Problème :** Firebase ne s'initialise pas correctement.

**Fix :**
1. Vérifier `lib/firebase_options.dart` :
   ```dart
   apiKey: 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo',
   projectId: 'presto-app-74abe',
   ```
2. Vérifier que `.firebaserc` contient :
   ```json
   "default": "presto-app-74abe"
   ```
3. Rebuild complet :
   ```bash
   flutter clean
   flutter pub get
   flutter build web --release
   ```

### Solution D : Google Sign-In ne fonctionne pas après déploiement

**Problème :** Fonctionne en local mais pas en production.

**Fix :**
1. Vérifier que le domaine de production est autorisé (voir Solution A)
2. Vérifier Google Cloud Console (voir Étape 3.C)
3. Vérifier que le Web Client ID dans `web/index.html` est correct :
   ```html
   <meta name="google-signin-client_id" content="151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com">
   ```
4. Redéployer :
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

### Solution E : Firestore "permission-denied"

**Problème :** Impossible de lire/écrire dans Firestore.

**Fix :**
1. Vérifier que l'utilisateur est bien connecté :
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   if (user == null) {
     // Pas connecté
   }
   ```
2. Vérifier les règles Firestore :
   ```bash
   firebase deploy --only firestore:rules
   ```
3. Vérifier dans Firebase Console → Firestore Database → Rules

---

## 🧪 Tests manuels dans la console navigateur

### Test 1 : Vérifier Firebase est initialisé
```javascript
// Ouvrir F12 → Console, puis taper :
firebase.apps.length
// Devrait retourner 1 (ou plus si plusieurs apps)
```

### Test 2 : Vérifier Auth instance
```javascript
firebase.auth().currentUser
// Si connecté : retourne l'objet user
// Si non connecté : retourne null
```

### Test 3 : Tester Google Sign-In manuellement
```javascript
const provider = new firebase.auth.GoogleAuthProvider();
firebase.auth().signInWithPopup(provider)
  .then(result => console.log('✅ Connecté:', result.user.email))
  .catch(error => console.error('❌ Erreur:', error));
```

---

## 📞 Checklist finale

Si tout échoue, vérifier dans l'ordre :

- [ ] **Firebase Console** → Authentication → Google est activé
- [ ] **Firebase Console** → Authentication → Authorized domains contient votre domaine
- [ ] **Google Cloud Console** → Credentials → Web client est configuré
- [ ] `lib/firebase_options.dart` contient les bonnes clés
- [ ] `web/index.html` contient le bon Client ID
- [ ] `firestore.rules` et `storage.rules` sont déployés
- [ ] `flutter clean && flutter build web` sans erreurs
- [ ] `firebase deploy --only hosting` réussi
- [ ] Test avec `test_firebase_connection.html` en local
- [ ] Test sur le site déployé en production

---

## 🚀 Rebuild et redéploiement complet

Si vous voulez repartir de zéro :

```bash
# 1. Nettoyer
flutter clean
rm -rf build/

# 2. Installer les dépendances
flutter pub get

# 3. Vérifier la configuration
./verify_firebase_config.sh

# 4. Builder
flutter build web --release

# 5. Déployer
firebase deploy --only hosting,firestore:rules,storage

# 6. Tester
open https://presto-app-74abe.web.app
```

---

## 📝 Logs de debug à activer

Pour avoir plus d'informations sur les erreurs, ajouter dans `profile_page.dart` :

```dart
Future<void> _onGoogleSignIn() async {
  debugPrint('🔵 [AUTH] Starting Google Sign-In');
  debugPrint('🔵 [AUTH] Platform: ${kIsWeb ? "Web" : "Native"}');
  debugPrint('🔵 [AUTH] Current user: ${_auth.currentUser?.email ?? "null"}');
  
  try {
    // ... code existant
  } catch (e) {
    debugPrint('🔴 [AUTH] Error: $e');
    debugPrint('🔴 [AUTH] Error type: ${e.runtimeType}');
    if (e is FirebaseAuthException) {
      debugPrint('🔴 [AUTH] Code: ${e.code}');
      debugPrint('🔴 [AUTH] Message: ${e.message}');
    }
  }
}
```

Puis regarder les logs dans la console VS Code lors du `flutter run -d chrome`.

---

**Date de création :** 6 janvier 2026  
**Status :** 🟢 Guide complet  
**Fichiers créés :**
- `test_firebase_connection.html` (page de test)
- `verify_firebase_config.sh` (script de vérification)
- `FIREBASE_DIAGNOSTIC.md` (diagnostic complet)
- `FIREBASE_FIX_GUIDE.md` (ce guide)
