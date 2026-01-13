# 🔐 Guide Sécurité Firebase Firestore API

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Configuration des Tokens](#configuration-des-tokens)
3. [Gestion des Secrets](#gestion-des-secrets)
4. [Restrictions de Clé API](#restrictions-de-clé-api)
5. [Authentification & Autorisation](#authentification--autorisation)
6. [Audit & Monitoring](#audit--monitoring)
7. [Checklist de Sécurité](#checklist-de-sécurité)

---

## Vue d'ensemble

### Tokens Publics vs Secrets

**Tokens PUBLICS (sans danger à exposer):**
- `apiKey` - Clé API Firebase restrictive
- `authDomain` - Domaine Firebase
- `projectId` - ID du projet
- `storageBucket` - Bucket de stockage
- `messagingSenderId` - ID pour FCM
- `appId` - ID de l'application

**Secrets PRIVÉS (ne JAMAIS exposer):**
- Clés de service (`service-account-key.json`)
- Tokens d'authentification utilisateur
- Mots de passe de base de données
- Variables d'environnement (`GMAIL_PASSWORD`, etc.)

### Architecture de Sécurité Presto App

```
┌─────────────────────────────────────────────────────────┐
│ Client (Web/Mobile)                                      │
│ - Firebase Options (public, restrictée par clé API)     │
│ - Firebase Auth (JWT tokens)                             │
└────────────────┬──────────────────────────────────────┘
                 │ (Signed Requests)
                 ▼
┌─────────────────────────────────────────────────────────┐
│ Firebase Services (Google Infrastructure)                │
│ - Firestore (Rules-based)                                │
│ - Cloud Storage (Rules-based)                            │
│ - Cloud Functions (Server-side)                          │
└────────────────┬──────────────────────────────────────┘
                 │ (Internal)
                 ▼
┌─────────────────────────────────────────────────────────┐
│ Backend Services                                         │
│ - Micro IA (Speech-to-Text)                             │
│ - Email Service (Moderation)                             │
│ - Monitoring & Analytics                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Configuration des Tokens

### 1. Firebase Options (`lib/firebase_options.dart`)

```dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo',
      authDomain: 'presto-app-74abe.firebaseapp.com',
      projectId: 'presto-app-74abe',
      storageBucket: 'presto-app-74abe.firebasestorage.app',
      messagingSenderId: '151421230024',
      appId: '1:151421230024:web:deb9b7cb4f744c742b3efd',
    );
  }
}
```

**Sécurité:**
- ✅ Intégrée dans l'app (pas d'API call externe)
- ✅ Restriction par clé API appliquée
- ✅ Pas d'authentification requise (utilisé par Auth)

### 2. Génération de Tokens Firebase

**Pour une nouvelle application:**

```bash
# Initialiser Firebase CLI
firebase init

# Récupérer les options actuelles
firebase apps:list

# Copier les tokens dans firebase_options.dart
# (générés automatiquement par Firebase CLI)
```

### 3. Valider les Tokens

```bash
# Exécuter le script de validation
bash validate_firebase_tokens.sh

# Résultat attendu: ✅ TOUS LES TOKENS FIREBASE SONT VALIDES
```

---

## Gestion des Secrets

### 1. Variables d'Environnement Cloud Functions

**Fichier: `functions/src/moderation.ts`**

```typescript
// Utiliser Firebase Params (v2) - Moderne & Sécurisé
import { defineString } from 'firebase-functions/params';

const gmailPassword = defineString('GMAIL_PASSWORD');
const gmailUser = defineString('GMAIL_USER');

// Utilisation
export const sendEmail = onDocumentCreated(async (event) => {
  const pass = await gmailPassword.value();
  const user = await gmailUser.value();
  
  // Transporter l'email avec credentials
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user, pass }
  });
});
```

**Avantages de Firebase Params v2:**
- ✅ Secrets chiffrés dans Google Cloud Secret Manager
- ✅ Jamais exposés dans les logs
- ✅ Rotation de secrets supportée
- ✅ Audit trail complet

### 2. Déployer les Secrets

```bash
# Méthode 1: Via CLI (recommandée pour production)
firebase deploy --set-env \
  GMAIL_USER="user@gmail.com" \
  GMAIL_PASSWORD="app-specific-password"

# Méthode 2: Fichier .env local (dev uniquement)
cat > functions/.env << EOF
GMAIL_USER=user@gmail.com
GMAIL_PASSWORD=app-specific-password
EOF

# ⚠️ IMPORTANT: Ne JAMAIS committer .env
# Vérifier .gitignore:
echo ".env" >> .gitignore
```

### 3. Secrets dans `.gitignore`

```bash
# ✅ Fichier .gitignore (OBLIGATOIRE)
.env
.env.*
.runtimeconfig.json
firebase-debug.log
firebase-debug.*.log
functions/lib/secrets.json
credentials.json
service-account-key.json
```

---

## Restrictions de Clé API

### 1. Configurer les Restrictions (Google Cloud Console)

**Lien:** https://console.cloud.google.com/apis/credentials

**Clé API actuelle:** `AIzaSyB-Oo_86VpG_refQU7my0qk10tQFQDU-Fo`

#### Étape 1: HTTP Referer Restrictions

```
https://stef25fwi.github.io/presto_app/*
https://presto-app-74abe.firebaseapp.com/*
https://presto-app-74abe.web.app/*
```

#### Étape 2: API Restrictions

✅ **Autorisées:**
- Cloud Firestore API
- Cloud Authentication API
- Cloud Storage for Firebase
- Firebase App Check Attestation API
- Firebase Management API

❌ **Désactiver:**
- Google Places API (utiliser proxy)
- YouTube Data API
- Maps API
- Autres APIs non utilisées

#### Étape 3: Vérification

```bash
# Tester depuis le CLI
curl "https://firestore.googleapis.com/v1/projects/presto-app-74abe/databases" \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)"
```

### 2. Monitorer l'Utilisation de la Clé API

```bash
# Google Cloud Console → APIs & Services → Quotas & System Limits
# Vérifier:
# - Requests/day (Firestore API)
# - Requests/minute
# - Erreurs d'authentification
```

---

## Authentification & Autorisation

### 1. Firebase Authentication

**Configuration dans `lib/main.dart`:**

```dart
// Initialiser Firebase Auth
final auth = FirebaseAuth.instance;

// Écouter les changements d'authentification
auth.authStateChanges().listen((User? user) {
  if (user == null) {
    // Utilisateur non connecté
    _handleSignOut();
  } else {
    // Utilisateur connecté (user.uid disponible)
    _handleSignIn(user.uid);
  }
});

// Sign In avec Google (exemple)
Future<void> signInWithGoogle() async {
  final googleUser = await GoogleSignIn().signIn();
  final googleAuth = await googleUser?.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth?.accessToken,
    idToken: googleAuth?.idToken,
  );
  await auth.signInWithCredential(credential);
}
```

### 2. Firestore Security Rules

**Fichier: `firestore.rules`**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ Offres (Lectures publiques, écritures restrictives)
    match /offers/{offerId} {
      allow read: if resource.data.isActive == true;
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.authorId;
      allow delete: if request.auth.uid == resource.data.authorId;
    }
    
    // ✅ Utilisateurs (Accès personnel)
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // ✅ Messages (Participants seulement)
    match /messages/{messageId} {
      allow read: if request.auth.uid in resource.data.participantIds;
      allow create: if request.auth != null;
    }
  }
}
```

### 3. Storage Security Rules

**Fichier: `storage.rules`**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // ✅ Fichiers publics (offres)
    match /offers/{offerId}/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // ✅ Fichiers STT (utilisateur seulement)
    match /stt/{uid}/{file} {
      allow read, write: if request.auth.uid == uid;
    }
    
    // ✅ Images de profil
    match /profile-images/{uid}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == uid;
    }
  }
}
```

---

## Audit & Monitoring

### 1. Logs Firebase

```bash
# Logs Cloud Functions
firebase functions:log --limit 100

# Filtrer les erreurs
firebase functions:log --limit 100 | grep ERROR

# Logs en temps réel
firebase functions:log --follow
```

### 2. Firestore Audit Logs

**Google Cloud Console → Logs → Cloud Audit Logs**

```
- Admin Activity
- Data Access (pour PII)
- System Events
```

### 3. Metrics & Quotas

**Firebase Console → Project Settings → Usage & Billing**

```
- Firestore Reads/Writes/Deletes
- Storage Operations
- Functions Invocations
- Authentication Sign-ins
```

### 4. Alertes Recommandées

```bash
# Dépasser 100K lectures/jour
# Dépasser 50K écritures/jour
# Erreurs d'authentification > 1% des requêtes
# Violations de règles de sécurité
```

---

## Checklist de Sécurité

### ✅ Avant le Déploiement

- [ ] Tous les tokens Firebase validés
  ```bash
  bash validate_firebase_tokens.sh
  ```

- [ ] Secrets non committés
  ```bash
  git status | grep ".env"  # Ne rien voir
  ```

- [ ] Restrictions de clé API configurées
  - [ ] HTTP Referer restrictions appliquées
  - [ ] Seules les APIs nécessaires autorisées

- [ ] Firestore Rules testées
  ```bash
  firebase emulators:start
  # Tester read/write access
  ```

- [ ] Storage Rules testées
  - [ ] Uploads personnels restreints par UID
  - [ ] Fichiers publics lisibles

- [ ] Cloud Functions scrutinées
  - [ ] Pas de secrets en dur
  - [ ] Utilisation de Firebase Params v2
  - [ ] Gestion d'erreurs complète

- [ ] Firebase App Check configuré
  - [ ] Provider: reCAPTCHA ou SafetyNet
  - [ ] Tokens validés avant Firestore

### ✅ Après le Déploiement

- [ ] Logs Firebase vérifiés (24h)
- [ ] Pas d'erreurs d'authentification
- [ ] Pas d'abus de quota
- [ ] Alertes de monitoring configurées
- [ ] Audit trail audité

### ✅ Maintenance Régulière

**Hebdomadaire:**
- [ ] Vérifier les erreurs Firebase Functions
- [ ] Vérifier les violations de règles Firestore

**Mensuel:**
- [ ] Rotation des secrets (optionnel si > 30 jours)
- [ ] Audit des utilisateurs actifs
- [ ] Vérifier les quotas (vs limites)

**Trimestriel:**
- [ ] Audit complet de sécurité
- [ ] Mise à jour des dépendances
- [ ] Révision des Firestore Rules

**Annuel:**
- [ ] Audit de conformité
- [ ] Pénétration testing
- [ ] Rotation complète des secrets

---

## Commandes Utiles

```bash
# Validation
bash validate_firebase_tokens.sh

# Déploiement des Secrets
firebase deploy --set-env GMAIL_USER="..." GMAIL_PASSWORD="..."

# Vérifier les Secrets déployés
firebase functions:config:get

# Logs
firebase functions:log --limit 100
firebase functions:log --follow

# Emulateurs (local testing)
firebase emulators:start

# Lister les apps
firebase apps:list

# Lister les projets
firebase projects:list

# Sélectionner un projet
firebase use presto-app-74abe
```

---

## Escalade & Support

**Pour les préoccupations de sécurité:**

1. **Google Cloud Console** → Security Command Center
2. **Firebase Console** → Project Settings → Security
3. **Google Cloud Support** (si premium)

**Contacts:**
- Firebase Support: https://firebase.google.com/support
- Google Cloud Security: https://cloud.google.com/security

---

## Ressources

- [Firebase Security Documentation](https://firebase.google.com/docs/rules)
- [Google Cloud IAM](https://cloud.google.com/iam/docs)
- [Cloud Functions Security](https://cloud.google.com/functions/docs/bestpractices/tips)
- [OWASP API Security](https://owasp.org/www-project-api-security/)

---

**Dernière mise à jour:** 13 Janvier 2026  
**Prochaine révision:** Avril 2026 (trimestrielle)
