# 🔧 Guide Complet - Configuration Google Sign-In sur Firebase

**Date**: 21 avril 2026  
**Problème**: Le bouton "Continuer avec Google" sur la page de profil ne fonctionne pas

---

## 📋 État Actuel du Projet

### ✅ Code Configuré
- **Client ID Web** (web/index.html): `151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com`
- **Firebase Project ID**: `presto-app-74abe`
- **Implementation**: Popup flow + Redirect fallback (AccountSocialAuthActions)

### ❌ Configuration Firebase/Google Cloud Incomplète
Les étapes suivantes doivent être faites manuellement dans les consoles Firebase et Google Cloud.

---

## 🚀 Étapes de Configuration (OBLIGATOIRES)

### ÉTAPE 1: Firebase Console - Authentication Setup
**URL**: https://console.firebase.google.com/project/presto-app-74abe/authentication

#### 1.1 Activer Google Sign-In Provider
1. Aller à **Authentication** → **Sign-in method**
2. Chercher **Google**
3. Cliquer sur **Google**
4. Basculer **Enable** → Bleu ✅
5. Laisser les autres options par défaut
6. **Enregistrer** (Save)

#### 1.2 Configurer les Domaines Autorisés
1. Aller à **Authentication** → **Settings** → **Authorized domains**
2. Ajouter **chaque domaine** suivant:
   - `localhost` (développement local)
   - `presto-app-74abe.web.app` (Firebase Hosting)
   - `presto-app-74abe.firebaseapp.com` (domaine par défaut)
   - `stef25fwi.github.io` (GitHub Pages - si applicable)
3. **Enregistrer**

---

### ÉTAPE 2: Google Cloud Console - OAuth Consent Screen
**URL**: https://console.cloud.google.com/apis/credentials/consent?project=presto-app-74abe

#### 2.1 Configuration du Consent Screen
1. Vérifier que le projet est bien **presto-app-74abe**
2. Cliquer **MODIFIER L'APPLICATION** (ou **CREATE**)
3. **User Type**: Sélectionner **External** (pour test)
4. Cliquer **CRÉER**

#### 2.2 Remplir les Infos de Base
- **Nom de l'app**: `Prestō` (ou `presto_app`)
- **Logo**: ✅ Optionnel
- **Support email**: Ajouter votre email de support
- **Domaines autorisés**: 
  ```
  presto-app-74abe.web.app
  presto-app-74abe.firebaseapp.com
  localhost
  ```
- **Developer contact**: Ajouter votre email
- **Enregistrer et continuer**

#### 2.3 Ajouter les Scopes
1. Cliquer **ADD OR REMOVE SCOPES**
2. Cocher les scopes suivants:
   - `.../auth/userinfo.email` (Email)
   - `.../auth/userinfo.profile` (Profil)
3. **METTRE À JOUR**
4. **Enregistrer et continuer**

#### 2.4 Ajouter Utilisateurs de Test (Optionnel)
1. Si en mode **External**, ajouter email test
2. **Enregistrer et continuer**

---

### ÉTAPE 3: Google Cloud Console - OAuth Client ID
**URL**: https://console.cloud.google.com/apis/credentials?project=presto-app-74abe

#### 3.1 Vérifier/Créer Client ID
1. Aller à **Credentials**
2. Chercher **Client ID** avec Type = **Web application**
3. Si n'existe pas:
   - Cliquer **+ CREATE CREDENTIALS** → **OAuth client ID**
   - Sélectionner **Web application**

#### 3.2 Configurer Client ID Web
Sélectionner/modifier le Web application client ID:

**Authorized JavaScript origins** (ajouter si manquant):
```
https://presto-app-74abe.web.app
https://presto-app-74abe.firebaseapp.com
http://localhost:5000
http://localhost:8080
http://localhost:3000
```

**Authorized redirect URIs** (TRÈS IMPORTANT):
```
https://presto-app-74abe.web.app/__/auth/handler
https://presto-app-74abe.firebaseapp.com/__/auth/handler
http://localhost:5000/__/auth/handler
http://localhost:8080/__/auth/handler
http://localhost:3000/__/auth/handler
```

3. Cliquer **METTRE À JOUR**
4. **Copier le Client ID** pour vérification

---

### ÉTAPE 4: Vérification du Code

#### 4.1 Vérifier web/index.html
```html
<!-- Line 33 - Google Sign-In Web Client ID -->
<meta name="google-signin-client_id" 
  content="151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com">
```
✅ **Correct** - Ne pas modifier

#### 4.2 Vérifier lib/firebase_options.dart
```dart
static const String _projectId = 'presto-app-74abe';
static const String _authDomain = 'presto-app-74abe.firebaseapp.com';
static const String _apiKey = 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo';
```
✅ **Correct** - Ne pas modifier

---

## 🧪 Test Étape par Étape

### Test Local (flutter run -d chrome)
1. Ouvrir l'app: `http://localhost:XXXX`
2. Aller à **Mon compte** → Page de login
3. Cliquer **Continuer avec Google**
4. ✅ **POPUP** Google s'ouvre
   - Sélectionner un compte Google
   - Cliquer **Continuer**
5. ✅ **SUCCÈS**: Message "✓ Connecté avec Google"
6. ✅ Redirection vers page de profil

### Test en Production (Firebase Hosting)
1. Déployer: `flutter build web && firebase deploy --only hosting`
2. Aller à: `https://presto-app-74abe.web.app`
3. Tester la connexion Google
4. ✅ **SUCCÈS**: Fonctionner comme en local

---

## ❌ Erreurs Courantes et Solutions

### Erreur: "unauthorized-domain"
**Cause**: Le domaine n'est pas dans la liste autorisée Firebase  
**Solution**: 
- Ajouter le domaine dans Firebase Console → Authentication → Authorized domains
- Attendre quelques minutes que la modification se propage

### Erreur: "operation-not-allowed"
**Cause**: Google Sign-In n'est pas activé dans Firebase  
**Solution**:
- Aller à Firebase Console → Authentication → Sign-in method
- Activer Google Provider
- Cliquer Save

### Erreur: "invalid-oauth-client"
**Cause**: Le Client ID est incorrect ou pas configuré  
**Solution**:
- Vérifier que web/index.html a le bon Client ID
- Vérifier dans Google Cloud que le Client ID existe

### Popup Bloquée
**Cause**: Navigateur bloque les popups  
**Solution**: 
- Le code a un fallback automatique → redirect flow
- Ou permettre les popups pour ce domaine dans le navigateur

---

## 📊 Checklist de Configuration

| Élément | Fichier | Location | Status |
|---------|---------|----------|--------|
| Client ID Web | web/index.html | Line 33 | ✅ Correct |
| Firebase Config | lib/firebase_options.dart | Entire file | ✅ Correct |
| Google Provider | Firebase Console | Authentication | ⚠️ À VÉRIFIER |
| Authorized Domains | Firebase Console | Authentication Settings | ⚠️ À VÉRIFIER |
| OAuth Consent | Google Cloud | APIs → OAuth consent | ⚠️ À VÉRIFIER |
| Client ID Config | Google Cloud | Credentials | ⚠️ À VÉRIFIER |
| JS Origins | Google Cloud | Client ID settings | ⚠️ À VÉRIFIER |
| Redirect URIs | Google Cloud | Client ID settings | ⚠️ À VÉRIFIER |

---

## 🔐 Sécurité

### ✅ Bonnes Pratiques Implémentées
- Client ID correctement configuré
- Scopes limités (email + profile seulement)
- Redirect flow avec gestion d'erreurs
- App Check possible pour ajouter plus tard

### 📌 À Faire
- Tester en mode **Internal** une fois configuré
- Activer App Check après tests initiaux (optionnel)
- Monitorer les logs Firebase pour déterminer les erreurs

---

## 📞 Support

Si vous rencontrez encore des problèmes:

1. **Vérifier la console navigateur** (F12)
   - Ouvrir DevTools → Console
   - Chercher les erreurs Firebase Auth
   - Noter les codes d'erreur spécifiques

2. **Vérifier les logs Firebase**
   - Firebase Console → Logs
   - Chercher les erreurs d'authentification

3. **Vérifier les scopes**
   - Le code demande: `email` + `profile`
   - Ces scopes doivent être autorisés dans Google Cloud

---

## 🎯 Prochaines Étapes

1. **IMMÉDIAT**: Configurer Firebase Console (ÉTAPE 1-2-3 ci-dessus)
2. **Test**: Vérifier que la connexion Google fonctionne
3. **Déploiement**: Déployer sur Firebase Hosting
4. **Production**: Activer App Check si nécessaire

---

**Dernière mise à jour**: 21 avril 2026
