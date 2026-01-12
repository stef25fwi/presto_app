# 🔥 Diagnostic Firebase - Presto App
*Généré le 6 janvier 2026*

## 📋 Configuration actuelle

### Firebase Project
- **Project ID**: `presto-app-74abe`
- **Auth Domain**: `presto-app-74abe.firebaseapp.com`
- **App ID**: `1:151421230024:web:8b83d1d11084c5a02b3efd`
- **API Key**: `AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo`
- **Storage Bucket**: `presto-app-74abe.firebasestorage.app`

### Plateforme
- **Cible**: Web (Flutter)
- **Hosting**: Firebase Hosting (`build/web`)
- **URL**: `https://presto-app-74abe.web.app`

✅ Choix long-terme recommandé : **Firebase Hosting** comme URL officielle (racine `/`).
Cela simplifie fortement Google Sign-In (moins de problèmes de `base-href`, routing et domaines autorisés).

---

## ⚠️ Problèmes identifiés

### 1. ❌ Paramètre `isDisabled` inutilisé
**Fichier**: `lib/main.dart` ligne 2453
**Problème**: Le paramètre optionnel `isDisabled` de la classe `_BottomNavItem` n'est jamais utilisé.
**Impact**: Warning de compilation
**Solution**: Supprimer le paramètre ou l'utiliser dans le widget

### 2. ⚠️ Domaines autorisés Firebase
**Fichier**: Firebase Console → Authentication → Authorized domains
**Problème potentiel**: Si vous testez localement ou sur un nouveau domaine, il doit être ajouté
**Domaines à vérifier**:
- `localhost` (développement local)
- `presto-app-74abe.web.app` (production Firebase)
- `presto-app-74abe.firebaseapp.com` (alternative)
- `stef25fwi.github.io` (si GitHub Pages utilisé)
- Domaine du Codespace GitHub (si applicable)

### 3. ⚠️ Configuration Google Sign-In
**Fichier**: `web/index.html` ligne 33
**Configuration actuelle**:
```html
<meta name="google-signin-client_id" content="151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com">
```
**À vérifier**:
- Ce Client ID doit être configuré dans **Google Cloud Console** → APIs & Services → Credentials
- Les **Authorized JavaScript origins** doivent inclure tous vos domaines
- Les **Authorized redirect URIs** doivent inclure: `https://presto-app-74abe.firebaseapp.com/__/auth/handler`

### 4. ⚠️ Firebase Authentication Provider
**Console Firebase**: Authentication → Sign-in method
**À vérifier**:
- ✅ Google Sign-In doit être **activé**
- ✅ Web SDK configuration doit utiliser le bon **Web client ID**
- ✅ Email/Password peut être activé si nécessaire

### 5. ⚠️ App Check non configuré
**Fichier**: `lib/main.dart` lignes 420-445
**État actuel**: App Check désactivé sur Web (pas de reCAPTCHA site key)
**Impact**: Les Cloud Functions peuvent rejeter les requêtes non vérifiées
**Solution**: Ajouter une clé reCAPTCHA v3 pour le Web

---

## 🧪 Tests à effectuer

### Test 1: Page de test Firebase
⚠️ Ne pas ouvrir en `file://` (les imports ES modules Firebase peuvent échouer).

Servir la page via HTTP, puis ouvrir l’URL :
```bash
python3 -m http.server 8000
"$BROWSER" http://localhost:8000/test_firebase_connection.html
```

1. Tester l'initialisation Firebase
2. Tester Firebase Auth instance
3. Tester Firestore instance
4. Tester Google Sign-In (popup)
5. Tester Google Sign-In (redirect)

### Test 2: Vérifier les erreurs dans la console
```bash
flutter run -d chrome --web-browser-flag="--disable-web-security"
```
Regarder la console JavaScript (F12) pour:
- Erreurs d'initialisation Firebase
- Erreurs CORS
- Erreurs de domaine non autorisé
- Erreurs de configuration OAuth

### Test 3: Vérifier Firebase Console
1. **Authentication → Users**: Voir si des utilisateurs sont créés après tentative de connexion
2. **Authentication → Sign-in methods**: Vérifier que Google est activé
3. **Authentication → Settings → Authorized domains**: Vérifier les domaines
4. **Project Settings → General**: Vérifier les Web Apps configurées

---

## 🔧 Solutions recommandées

### Solution 1: Nettoyer le code
```dart
// Supprimer le paramètre isDisabled non utilisé
class _BottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isBig;
  // final bool isDisabled; // ❌ À SUPPRIMER
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isBig = false,
    // this.isDisabled = false, // ❌ À SUPPRIMER
  });
```

### Solution 2: Vérifier OAuth Configuration
**Google Cloud Console** → APIs & Services → Credentials → Web client
**Authorized JavaScript origins**:
```
https://presto-app-74abe.web.app
https://presto-app-74abe.firebaseapp.com
http://localhost
http://localhost:5000
```

**Authorized redirect URIs**:
```
https://presto-app-74abe.firebaseapp.com/__/auth/handler
http://localhost/__/auth/handler
```

### Solution 3: Ajouter App Check (optionnel mais recommandé)
1. **Firebase Console** → App Check → Register web app
2. Obtenir la **reCAPTCHA v3 site key**
3. Ajouter dans le build:
```bash
flutter build web --dart-define=APPCHECK_RECAPTCHA_SITE_KEY=6Lxxxxx...
```

### Solution 4: Débugger l'authentification
Activer les logs détaillés dans `profile_page.dart`:
```dart
Future<void> _onGoogleSignIn() async {
  debugPrint('🔵 [AUTH] Starting Google Sign-In...');
  debugPrint('🔵 [AUTH] Current user: ${_auth.currentUser?.email ?? "null"}');
  debugPrint('🔵 [AUTH] Platform: ${kIsWeb ? "Web" : "Native"}');
  
  // ... reste du code avec logs enrichis
}
```

---

## 📝 Checklist de vérification

### Configuration Firebase
- [ ] Project ID correct dans `.firebaserc` et `firebase_options.dart`
- [ ] API Key valide et non révoquée
- [ ] App ID Web configuré dans Firebase Console
- [ ] Firestore rules déployées: `firebase deploy --only firestore:rules`
- [ ] Storage rules déployées: `firebase deploy --only storage`

### Authentication
- [ ] Google Sign-In activé dans Firebase Console
- [ ] Web Client ID configuré dans Google Cloud Console
- [ ] Domaines autorisés ajoutés dans Firebase Authentication
- [ ] Redirect URIs configurées dans Google Cloud Console
- [ ] Test de connexion réussi dans `test_firebase_connection.html`

### Code
- [ ] `Firebase.initializeApp()` appelé dans `main()`
- [ ] `FirebaseAuth.instance` accessible
- [ ] `FirebaseFirestore.instance` accessible
- [ ] Pas d'erreurs de compilation (warning `isDisabled`)
- [ ] Logs de debug activés pour tracer les problèmes

### Déploiement
- [ ] `flutter build web --release` sans erreurs
- [ ] `firebase deploy --only hosting` réussi
- [ ] Site accessible sur `presto-app-74abe.web.app`
- [ ] Test de connexion sur le site en production

---

## 🚀 Commandes utiles

### Rebuild complet
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Rebuild Web (Firebase Hosting) — recommandé
Utilise le script dédié (base-href `/`) :
```bash
./build_web_firebase_hosting.sh
```

### Deploy Firebase
```bash
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### Test local
```bash
flutter run -d chrome
# Ou avec serveur local Firebase
firebase serve --only hosting
```

### Logs Firebase
```bash
firebase functions:log
firebase firestore:indexes
```

---

## 📞 Support

Si le problème persiste après ces vérifications :

1. **Vérifier les logs navigateur** (Console F12)
2. **Vérifier Firebase Console** → Project Overview → Health
3. **Tester avec `test_firebase_connection.html`** pour isoler le problème
4. **Vérifier les quotas Firebase** (Authentication, Firestore, Storage)
5. **Contacter le support Firebase** si problème de quota ou de configuration serveur

---

## 🔍 Diagnostic rapide

```bash
# Vérifier version Flutter
flutter --version

# Vérifier packages Firebase
flutter pub deps | grep firebase

# Vérifier Firebase CLI
firebase --version

# Vérifier projet actif
firebase projects:list
```

---

**Date de dernière mise à jour**: 6 janvier 2026
**Status**: 🟡 En investigation
**Prochain step**: Tester avec `test_firebase_connection.html`
