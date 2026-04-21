# ✅ Checklist Configuration Firebase & Google Cloud

**Projet**: presto_app  
**Firebase Project ID**: `presto-app-74abe`  
**Google Cloud Project**: `presto-app-74abe`  
**Date**: 21 avril 2026

---

## 🎯 Statut Global

- ✅ Code correctement implémenté
- ❌ Configuration Firebase/Google Cloud INCOMPLÈTE
- 🔧 Configuration requise sur les consoles

---

## 📋 Configuration OBLIGATOIRE sur Firebase Console

### 1️⃣ Firebase Console → Authentication → Sign-in method

**URL**: https://console.firebase.google.com/project/presto-app-74abe/authentication

#### Google Provider Configuration
```
☐ Provider: Google
  ☐ Enable: ON (toggle bleu)
  ☐ Web SDK configuration: Doit s'afficher automatiquement
  ☐ Save (Enregistrer)
```

**Résultat attendu**: 
```
✅ Google authentication enabled
```

---

### 2️⃣ Firebase Console → Authentication → Settings → Authorized domains

**URL**: https://console.firebase.google.com/project/presto-app-74abe/authentication/settings

#### Domaines à Ajouter
```
Domaines autorisés:
  ☐ localhost
  ☐ presto-app-74abe.web.app
  ☐ presto-app-74abe.firebaseapp.com
  ☐ stef25fwi.github.io (optionnel - si vous utilisez GitHub Pages)
```

**Statut**: ⚠️ **À FAIRE**

**Instructions**:
1. Cliquer **ADD DOMAIN**
2. Taper `localhost` et appuyer sur Enter
3. Répéter pour chaque domaine
4. **Enregistrer**

---

## 🌐 Configuration OBLIGATOIRE sur Google Cloud Console

### 3️⃣ Google Cloud → APIs & Services → OAuth consent screen

**URL**: https://console.cloud.google.com/apis/credentials/consent?project=presto-app-74abe

#### Étapes

**1. Sélectionner le type d'application**
```
☐ User Type: External (pour applications en test)
   (Changer à Internal une fois en production)
☐ Cliquer CREATE
```

**2. Remplir les informations d'application**
```
Informations de base:
  ☐ Nom de l'application: Prestō
  ☐ Logo: (optionnel - vous pouvez ajouter assets/images/logo.png)
  ☐ Support email pour les utilisateurs: votre.email@example.com
  ☐ Developer contact information:
      ☐ Email: votre.email@example.com
  ☐ Cliquer SAVE AND CONTINUE
```

**3. Ajouter les scopes**
```
☐ Cliquer ADD OR REMOVE SCOPES
☐ Sélectionner les scopes:
   ☐ .../auth/userinfo.email
   ☐ .../auth/userinfo.profile
☐ Cliquer UPDATE
☐ Cliquer SAVE AND CONTINUE
```

**4. Utilisateurs de test (optionnel)**
```
☐ Si mode External, vous pouvez ajouter:
   ☐ Email des testeurs
☐ Cliquer ADD USERS
☐ SAVE AND CONTINUE
```

**5. Summary**
```
☐ Vérifier les informations
☐ BACK TO DASHBOARD
```

**Statut**: ⚠️ **À FAIRE**

---

### 4️⃣ Google Cloud → APIs & Services → Credentials

**URL**: https://console.cloud.google.com/apis/credentials?project=presto-app-74abe

#### Vérifier/Créer OAuth Client ID

**Rechercher le Client ID Web**
```
1. Aller à Credentials
2. Chercher une ligne avec:
   - Name: "presto_app" ou similaire
   - Type: "OAuth 2.0 Client ID"
   - Application type: "Web application"

Si existe:
  ☐ Cliquer dessus pour l'éditer
Si n'existe pas:
  ☐ Cliquer "+ CREATE CREDENTIALS"
  ☐ Sélectionner "OAuth client ID"
  ☐ Sélectionner "Web application"
  ☐ Name: "presto_app"
```

#### Configurer les Authorized JavaScript origins

```
Authorized JavaScript origins:
  ☐ https://presto-app-74abe.web.app
  ☐ https://presto-app-74abe.firebaseapp.com
  ☐ http://localhost:5000 (pour flutter serve)
  ☐ http://localhost:8080 (alternative)
  ☐ http://localhost:3000 (alternative)
  
⚠️ IMPORTANT: Inclure https:// pour les domaines de production
```

#### Configurer les Authorized redirect URIs

```
Authorized redirect URIs:
  ☐ https://presto-app-74abe.web.app/__/auth/handler
  ☐ https://presto-app-74abe.firebaseapp.com/__/auth/handler
  ☐ http://localhost:5000/__/auth/handler
  ☐ http://localhost:8080/__/auth/handler
  ☐ http://localhost:3000/__/auth/handler
```

#### Sauvegarder et Vérifier

```
☐ Cliquer SAVE
☐ Copier le Client ID:
   Client ID: 151421230024-lung00ghpcc0qgbukvo29og1kuapnggf.apps.googleusercontent.com
   ✅ Vérifier qu'il correspond à celui dans web/index.html
```

**Statut**: ⚠️ **À FAIRE**

---

## 🧪 Test de Configuration

### Test Local

```bash
# 1. Flutter clean & rebuild
flutter clean
flutter build web

# 2. Lancer en développement
flutter run -d chrome

# 3. Actions dans l'app:
#    - Aller à la page "Mon compte"
#    - Cliquer "Continuer avec Google"
#    - Popup Google doit s'ouvrir
#    - Sélectionner un compte
#    - Message de succès: "✓ Connecté avec Google"
```

**Résultats attendus**:
```
✅ Popup s'ouvre
✅ Authentification réussie
✅ Redirection vers page de profil
✅ Message de succès affiché
```

### Test Production (Firebase Hosting)

```bash
# 1. Build web release
flutter build web --release

# 2. Deploy sur Firebase Hosting
firebase deploy --only hosting

# 3. Tester sur https://presto-app-74abe.web.app
#    - Même procédure que le test local
#    - Vérifier que tout fonctionne
```

---

## 🐛 Dépannage

### Erreur: "unauthorized-domain"
```
Cause: Le domaine n'est pas autorisé dans Firebase
Solution:
  1. Aller à Firebase Console → Authentication → Settings
  2. Ajouter le domaine dans "Authorized domains"
  3. Attendre 5-10 minutes pour la propagation
  4. Réessayer
```

### Erreur: "operation-not-allowed"
```
Cause: Google Sign-In n'est pas activé
Solution:
  1. Aller à Firebase Console → Authentication → Sign-in method
  2. Vérifier que Google est Enable (bleu)
  3. Si non, cliquer sur Google et activer
  4. Enregistrer
```

### Erreur: "invalid-oauth-client"
```
Cause: Le Client ID est incorrect ou le projet Google Cloud n'est pas configuré
Solution:
  1. Vérifier le Client ID dans web/index.html
  2. Vérifier que le Client ID existe dans Google Cloud Console
  3. Vérifier les Authorized JavaScript origins dans Google Cloud
  4. Vérifier les Authorized redirect URIs dans Google Cloud
```

### Popup Bloquée
```
Cause: Le navigateur bloque les popups
Comportement attendu:
  1. Le code détecte la popup bloquée
  2. Fallback automatique vers redirect flow
  3. Redirection vers Google
  4. Retour après authentification
Solution:
  - Permettre les popups pour ce domaine dans le navigateur
  - Ou utiliser le fallback redirect (fonctionnement normal)
```

---

## 📊 Résumé Configuration

| Configuration | Statut | Lien |
|---------------|--------|------|
| Code - Client ID Web | ✅ OK | web/index.html:33 |
| Code - Firebase Config | ✅ OK | lib/firebase_options.dart |
| Code - Implementation | ✅ OK | lib/services/account_social_auth_actions.dart |
| Firebase - Google Provider | ❌ À faire | [Console Firebase](https://console.firebase.google.com/project/presto-app-74abe/authentication) |
| Firebase - Authorized Domains | ❌ À faire | [Console Firebase](https://console.firebase.google.com/project/presto-app-74abe/authentication/settings) |
| Google Cloud - OAuth Consent | ❌ À faire | [Console Google Cloud](https://console.cloud.google.com/apis/credentials/consent?project=presto-app-74abe) |
| Google Cloud - Client ID | ❌ À faire | [Console Google Cloud](https://console.cloud.google.com/apis/credentials?project=presto-app-74abe) |

---

## 📌 Points Importants

1. **🔐 Sécurité**
   - Les Client IDs sont visibles en frontend (c'est normal)
   - Les API Keys sont visibles en frontend (c'est normal)
   - La sécurité vient de la configuration Firebase (domaines autorisés, etc.)

2. **🌐 Domaines**
   - `localhost` est nécessaire pour le développement local
   - `presto-app-74abe.web.app` est le domaine Firebase Hosting
   - `presto-app-74abe.firebaseapp.com` est le domaine par défaut Firebase

3. **🔄 Redirect Flow**
   - Si popup est bloquée, le code bascule automatiquement en redirect flow
   - L'utilisateur est redirigé vers Google, puis revient à votre app
   - Pas besoin de configuration spéciale - elle fonctionne automatiquement

4. **⏱️ Propagation**
   - Les modifications peuvent prendre 5-10 minutes à se propager
   - Si erreur persiste, vider le cache du navigateur et réessayer

---

## ✨ Prochain Étape

Après configuration:
1. Tester en développement local (`flutter run -d chrome`)
2. Tester en production sur Firebase Hosting
3. Vérifier les logs dans Firebase Console si problème

**Vous êtes prêt!** Suivez les étapes ci-dessus et contactez le support si vous rencontrez des problèmes.

---

**Dernière mise à jour**: 21 avril 2026
