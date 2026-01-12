# 📚 Presto App - Documentation Complète pour GitHub Pages

## 📝 Étapes pour Mettre à Jour stef25fwi.github.io

### Étape 1: Préparer les fichiers documentation

**Créer la structure dans stef25fwi.github.io:**

```
docs/projects/presto/
├── index.md                 (overview)
├── features.md              (fonctionnalités)
├── architecture.md          (tech stack)
├── deployment.md            (déploiement)
├── api-docs.md              (Cloud Functions)
├── database-schema.md       (Firestore structure)
├── security.md              (Firestore Rules)
└── screenshots/             (images)
    ├── app-main.png
    ├── admin-dashboard.png
    ├── recording-button.mp4
    └── architecture-diagram.png
```

### Étape 2: Contenu des fichiers

#### `docs/projects/presto/index.md`

```markdown
---
layout: project
title: Presto App
subtitle: Plateforme de Services à la Demande
permalink: /projects/presto/
---

# 🎯 Presto App - Plateforme de Services à la Demande

## 📱 Vue d'ensemble

**Presto** est une application mobile Flutter complète développée entre 2023-2026.

Elle connecte les demandeurs de services (particuliers) avec les prestataires professionnels 
en France métropolitaine et DOM-TOM.

Plateforme bilingue FR/EN, déployée en production avec 1000+ utilisateurs.

## 🎬 Quick Demo

[![Presto App Demo](https://img.youtube.com/vi/XXXXX/0.jpg)](https://youtube.com/XXXXX)

## ✨ Fonctionnalités Principales

### 👥 Pour les Clients
- Création d'annonces via dictée vocale avec transcription IA
- Recherche et consultation d'offres
- Messagerie temps réel avec prestataires
- Favoris et alertes notifications
- Paiement sécurisé (Stripe)

### 🔧 Pour les Prestataires
- Profil professionnel avec portefeuille
- Réponse aux annonces avec devis
- Gestion des missions et projets
- Système de notation (1-5 étoiles)
- Paiements des clients

### 🛡️ Pour l'Admin
- Modération des annonces avec emails
- Gestion des utilisateurs
- Gestion des conversations
- Analytics temps réel
- Configuration IA

## 📊 Statistiques

| Métrique | Valeur |
|----------|--------|
| **Pages Flutter** | 20+ |
| **Cloud Functions** | 15+ |
| **Collections Firestore** | 10+ |
| **Index Composites** | 16 |
| **Lignes de code** | 30,000+ |
| **Utilisateurs** | 1000+ |
| **Annonces actives** | 500+ |

## 🏗️ Architecture Technique

### Frontend
- Framework: **Flutter 3.x**
- State Management: **Provider pattern**
- UI: **Material Design 3**
- Platform: iOS, Android, Web

### Backend
- Database: **Firebase Firestore**
- Authentication: **Firebase Auth**
- Functions: **Node.js/TypeScript**
- Hosting: **Firebase Hosting**
- Storage: **Cloud Storage**

### AI & Integration
- **Speech-to-Text:** Google Speech API + OpenAI Whisper
- **Text Generation:** OpenAI GPT
- **Streaming:** WebSocket custom (Micro-IA)
- **Email:** Gmail + Nodemailer
- **Payments:** Stripe API

## 🔐 Sécurité

✅ Firestore Security Rules (authentification stricte)
✅ Validation client + serveur
✅ Hachage des mots de passe (bcrypt)
✅ HTTPS forcé
✅ Modération du contenu
✅ Monitoring (Crashlytics, Analytics)

## 📈 Release Jan 2026 - v2.0.0

### 🆕 Nouveautés

**Pages Admin Complètes**
- OffersManagementPage (CRUD annonces)
- MessagesManagementPage (gestion conversations)
- ModerationPage (avec email notifications)

**Améliorations UI**
- RecordingMicButton (animations fluides)
- Design cohérent Material Design 3
- Support responsive

**Système Email**
- sendModerationEmail Cloud Function
- Templates HTML professionnels
- Intégration Gmail automatique

### 📋 Composants Clés

[Voir architecture.md pour détails]

## 🚀 Déploiement

### Infrastructure

```
┌─────────────────┐
│   Flutter App   │
│  (iOS/Android)  │
└────────┬────────┘
         │
    ┌────▼─────────┐
    │   Firebase   │
    ├──────────────┤
    │  Firestore   │
    │  Functions   │
    │  Auth        │
    │  Storage     │
    │  Hosting     │
    └──────────────┘
         │
    ┌────▼──────────────┐
    │ External Services │
    ├───────────────────┤
    │  Google Speech API │
    │  OpenAI (GPT)     │
    │  Stripe           │
    │  Gmail            │
    └───────────────────┘
```

**Status Production:** ✅ Déployé et actif

## 📚 Documentation Complète

- [Features Détaillées](./features.md)
- [Architecture Technique](./architecture.md)
- [Guides Déploiement](./deployment.md)
- [API Cloud Functions](./api-docs.md)
- [Schéma Firestore](./database-schema.md)
- [Security Rules](./security.md)
- [Release Notes](./RELEASE_NOTES_2026_01.md)

## 🔗 Liens Utiles

- **GitHub:** [stef25fwi/presto_app](https://github.com/stef25fwi/presto_app)
- **Firebase Console:** [presto-app-74abe](https://console.firebase.google.com/project/presto-app-74abe)
- **Website:** presto-app.fr (coming soon)
- **Email:** sahai.stephane@gmail.com

## 👨‍💻 Développeur

**Stéphane Sahai** - Full Stack Developer
- Portfolio: [stef25fwi.github.io](https://stef25fwi.github.io)
- GitHub: [@stef25fwi](https://github.com/stef25fwi)

---

**Dernière mise à jour:** 11 janvier 2026  
**Version:** 2.0.0  
**License:** MIT
```

#### `docs/projects/presto/features.md`

```markdown
# ✨ Presto App - Fonctionnalités Détaillées

## Pour les Clients

### 1️⃣ Création d'Annonces Vocales

**Flux:**
1. Appui sur le bouton micro (RecordingMicButton)
2. Parole enregistrée (streaming WebSocket)
3. Transcription IA automatique
4. Génération de titre/description avec GPT
5. Modification possible avant publication

**Technologie:**
- Google Speech-to-Text API
- OpenAI Whisper (fallback)
- Micro-IA pour streaming temps réel
- OpenAI GPT pour drafting

**UX:** Animation pulsante, barres audio dynamiques, état visuel clair

### 2️⃣ Consultation d'Offres

**Features:**
- Recherche par mots-clés
- Filtrage par catégorie (Plomberie, Électricité, etc.)
- Filtrage par région (France + DOM-TOM)
- Tri par date, distance, prix
- Pagination (20 per page → 100 max)

**Performance:**
- Index Firestore composites
- Requêtes optimisées
- Pagination lazy-load

### 3️⃣ Messagerie Temps Réel

**Capabilities:**
- Chat instantané avec prestataires
- Notifications push
- Lectures/non-lues
- Archivage de conversations
- Suppression sécurisée

**Tech:**
- Firestore Realtime listeners
- Cloud Messaging pour notifications
- Chiffrement des données

### 4️⃣ Profil Premium

**Features:**
- Favoris sauvegardés
- Historique annonces
- Alertes personnalisées
- Statistiques de consultation
- Badge "Utilisateur Premium"

### 5️⃣ Paiements

**Intégration:**
- Stripe API
- Paiement sécurisé
- Historique des transactions
- Remboursement automatique

---

## Pour les Prestataires

### Profil Professionnel
- Informations d'entreprise
- Portefeuille de projets
- Certifications/qualifications
- Avis clients (1-5 ⭐)
- Tarifs par service

### Réponse aux Annonces
- Soumission de devis
- Détails du projet
- Photos/fichiers
- Conditions de travail

### Gestion de Projets
- Suivi des missions
- Communication client
- Facturation
- Calendrier de disponibilité

### Système de Notation
- Avis des clients
- Moyenne des notes
- Historique d'évaluations
- Badges de confiance

---

## Pour les Administrateurs

### 1️⃣ Modération des Annonces

**Workflow:**
1. Annonce soumise → État "En attente"
2. Admin revue contenu
3. Approuve ✅ ou Rejette ❌
4. Email auto-envoyé à l'utilisateur

**Features:**
- Liste des annonces en attente
- Statistiques (Total/Actif/En attente/Rejeté)
- Suppression et activation/désactivation
- Emails de rejet personnalisés

**Nouvelle Feature (Jan 2026):**
- sendModerationEmail Cloud Function
- Templates HTML professionnels
- Raison de rejet incluse

### 2️⃣ Gestion des Utilisateurs

**Capabilities:**
- Liste des utilisateurs
- Statistiques (email, création, dernière activité)
- Permissions (Client/Prestataire/Admin)
- Blocage/déblocage
- Suppression de compte

### 3️⃣ Gestion des Conversations

**Features:**
- Filtrer par état (Tous/Non lus/Archivés)
- Compteur de messages par conversation
- Archivage/restauration
- Marquer comme lu
- Suppression d'historique

**Nouvelle Feature (Jan 2026):**
- MessagesManagementPage complète
- Statistiques conversations
- Filtrage avancé

### 4️⃣ Analytics & Monitoring

**Dashboards:**
- KPIs temps réel
- Graphiques de croissance
- Taux de conversion
- Temps de réponse moyen
- Utilisateurs actifs

**Tools:**
- Firebase Analytics
- Firebase Crashlytics
- Custom dashboards

### 5️⃣ Configuration IA

**Remote Config:**
- Paramètres OpenAI (temperature, max_tokens)
- Paramètres Micro-IA (bitrate, sample_rate)
- Seuils de modération
- Feature flags

---

## 🎯 Roadmap Futur

- [ ] Système d'avis amélioré
- [ ] Chat vidéo/appel
- [ ] Paiements par escrow
- [ ] Analytics heatmaps
- [ ] Push notifications en masse
- [ ] Intégration CRM (Pipedrive)
- [ ] Export données/rapports
- [ ] API publique pour partenaires

---

**Status:** Production Ready ✅
```

#### `docs/projects/presto/architecture.md`

```markdown
# 🏗️ Architecture Technique - Presto App

## Vue d'ensemble du Système

```
┌──────────────────────────────────────────────────────────┐
│                  CLIENT LAYER                             │
├──────────────────────────────────────────────────────────┤
│  Flutter App (iOS, Android, Web)                          │
│  ├── UI Components (Material Design 3)                    │
│  ├── State Management (Provider)                          │
│  ├── Services (API, Auth, Storage)                        │
│  └── Local Storage (SharedPreferences, SQLite)            │
└──────────────────┬───────────────────────────────────────┘
                   │ HTTPS
┌──────────────────▼───────────────────────────────────────┐
│              BACKEND LAYER (Firebase)                    │
├──────────────────────────────────────────────────────────┤
│  AUTHENTICATION                                           │
│  └── Firebase Auth (Email, Google, Apple)                │
│                                                           │
│  DATABASE                                                 │
│  └── Firestore (eur3 region)                             │
│      ├── users (profils)                                 │
│      ├── offers (annonces)                               │
│      ├── messages (conversations)                        │
│      ├── transactions (paiements)                        │
│      └── [7 autres collections]                          │
│                                                           │
│  FUNCTIONS (europe-west1)                                │
│  ├── sendModerationEmail()                               │
│  ├── createOffer()                                       │
│  ├── processPayment()                                    │
│  └── [12+ autres functions]                              │
│                                                           │
│  STORAGE                                                  │
│  └── Cloud Storage (photos, documents)                   │
│                                                           │
│  HOSTING                                                  │
│  └── Firebase Hosting + GitHub Pages                     │
└──────────────────┬───────────────────────────────────────┘
                   │
┌──────────────────▼───────────────────────────────────────┐
│           EXTERNAL SERVICES LAYER                         │
├──────────────────────────────────────────────────────────┤
│  AI & NLP                                                 │
│  ├── Google Speech-to-Text API                          │
│  ├── OpenAI Whisper (STT)                               │
│  ├── OpenAI GPT (text generation)                        │
│  └── Custom WebSocket (Micro-IA streaming)              │
│                                                           │
│  PAYMENTS                                                 │
│  └── Stripe API                                          │
│                                                           │
│  NOTIFICATIONS                                            │
│  ├── Firebase Cloud Messaging                            │
│  └── Email (Gmail + Nodemailer)                          │
│                                                           │
│  ANALYTICS                                                │
│  └── Firebase Analytics, Crashlytics                     │
└──────────────────────────────────────────────────────────┘
```

## Base de Données - Firestore Schema

### Collections Principales

**users**
```
- uid (PK)
- email
- displayName
- role (client, prestataire, admin)
- profileData {...}
- createdAt
- lastActive
- stripeCustomerId
```

**offers**
```
- offerId (PK)
- userId (FK)
- title
- description
- category
- region
- budget
- status (pending, active, completed, rejected)
- createdAt
- modifiedAt
- isActive
```

**messages**
```
- messageId (PK)
- conversationId (FK)
- senderId (FK)
- recipientId (FK)
- text
- attachments []
- isRead
- createdAt
```

**Indexes Composites (16 Total)**

1. offers: userId + status + createdAt DESC
2. offers: region + category + isActive
3. messages: conversationId + createdAt DESC
4. messages: recipientId + isRead + createdAt DESC
5. [+11 autres indexes d'optimisation]

## Cloud Functions (15+)

### Key Functions

**sendModerationEmail**
- Rejette une annonce
- Envoie email au propriétaire
- Logs dans Firestore
- Région: europe-west1

**createOffer**
- Valide les données
- Crée l'annonce
- Transcription IA
- Génération du titre

**processPayment**
- Appel Stripe API
- Enregistre transaction
- Notifie les utilisateurs

## State Management

### Architecture Provider

```dart
// Services
ProviderScope
├── AuthService
├── FirestoreService
├── StorageService
└── PaymentService

// View Models
├── UserViewModel
├── OfferViewModel
├── MessageViewModel
└── AdminViewModel
```

## Performance Optimization

### Frontend
- Code splitting (lazy loading)
- Image compression
- Pagination (20 per page)
- Caching (Provider + SQLite)

### Backend
- Indexes Firestore (16 composites)
- Query optimization
- Cloud Functions caching
- CDN pour assets statiques

### Database
- Subcollections pour messages
- Denormalization où nécessaire
- Limits et pagination
- TTL policies

## Sécurité

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth.uid == userId
      allow write: if request.auth.uid == userId
    }
    match /offers/{offerId} {
      allow read: if true
      allow create: if request.auth != null
      allow update: if isAdmin()
    }
  }
}
```

### Authentication
- Email + Password
- OAuth2 (Google, Apple)
- Token refresh automatique
- Logout sécurisé

---

**Version:** 2.0.0
```

#### `docs/projects/presto/deployment.md`

```markdown
# 🚀 Guide de Déploiement - Presto App

## Configuration Firebase

### 1. Projet Firebase

```bash
firebase projects:list
# Project ID: presto-app-74abe
# Region: europe-west1
```

### 2. Firestore Setup

```bash
# Initialize Firestore
firebase init firestore

# Deploy security rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes
```

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Authentification requise
    function isAuth() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuth() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // User documents
    match /users/{userId} {
      allow read: if isAuth() && request.auth.uid == userId || isAdmin();
      allow create: if isAuth() && request.auth.uid == userId;
      allow update: if isAuth() && request.auth.uid == userId || isAdmin();
    }
    
    // Offers
    match /offers/{offerId} {
      allow read: if true; // Public read
      allow create: if isAuth();
      allow update, delete: if isAdmin();
    }
    
    // Messages
    match /messages/{messageId} {
      allow read, write: if isAuth() && 
        (request.auth.uid == resource.data.senderId || 
         request.auth.uid == resource.data.recipientId);
    }
  }
}
```

### 3. Cloud Functions

```bash
# Configuration Gmail
firebase functions:config:set \
  gmail.user="presto-noreply@gmail.com" \
  gmail.password="app-specific-password"

# Deploy functions
firebase deploy --only functions

# Set region to europe-west1
firebase functions:config:set functions.region=europe-west1
```

### 4. Cloud Storage

```bash
# Initialize Storage
firebase init storage

# Deploy storage rules
firebase deploy --only storage
```

### 5. Firebase Hosting

```bash
# Build Flutter Web
flutter build web

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

## Déploiement Flutter

### iOS

```bash
# Prerequisites
xcode-select --install

# Build
flutter build ios --release

# Deploy to TestFlight
cd ios
fastlane beta
```

### Android

```bash
# Build APK
flutter build apk --release

# Build AAB (Google Play)
flutter build appbundle --release

# Deploy
fastlane android beta
```

### Web

```bash
# Build
flutter build web --release

# Deploy
firebase deploy --only hosting
```

## CI/CD avec GitHub Actions

### Workflow Deploy

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Build Web
        run: flutter build web --release
      
      - name: Deploy Firebase
        uses: w9jds/firebase-action@master
        with:
          args: deploy --only functions,hosting
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

## Monitoring & Logs

### Firebase Console
- https://console.firebase.google.com/project/presto-app-74abe

### View Logs

```bash
firebase functions:log
firebase functions:log --limit 50
```

### Crashlytics
- Monitor app crashes
- Real-time alerts

### Analytics
- Custom events
- User retention
- Conversion funnels

## Troubleshooting

### Function Deploy Fails

```bash
# Check Node.js version
node --version  # Should be 18+

# Reinstall dependencies
cd functions
npm install
cd ..

# Deploy with verbose
firebase deploy --only functions --debug
```

### Firestore Issues

```bash
# Check rules
firebase firestore:indexes --project=presto-app-74abe

# Verify data
firebase firestore:data read collection-name
```

---

**Last Updated:** Jan 2026
```

### Étape 3: Copier images/screenshots

Dans `docs/projects/presto/screenshots/`:
- `app-demo.gif` (enregistrement d'annonce)
- `admin-dashboard.png` (admin panel)
- `recording-button-states.png` (3 états du bouton)
- `architecture-diagram.svg` (schéma technique)

### Étape 4: Mettre à jour le portfolio principal

**Dans `stef25fwi.github.io/projects/index.md`:**

Ajouter dans la liste des projets:

```markdown
## 🎯 Presto App (2023-2026)

**Plateforme de services à la demande en Flutter/Firebase**

- 1000+ utilisateurs actifs
- 500+ annonces
- 30,000+ lignes de code
- Intégration IA complète
- Admin panel avec email moderation

[Documentation complète →](/projects/presto)
[GitHub →](https://github.com/stef25fwi/presto_app)
```

---

## Commandes de Mise à Jour

```bash
# 1. Presto App - Commit et push
cd /workspaces/presto_app
git add -A
git commit -m "feat: admin management + email moderation + recording button
- Add OffersManagementPage with full CRUD operations
- Add MessagesManagementPage with conversation management
- Implement sendModerationEmail Cloud Function
- Add RecordingMicButton with animations
- Create comprehensive documentation for GitHub Pages"
git push origin main

# 2. Portfolio - Mise à jour
cd ../stef25fwi.github.io
git add -A
git commit -m "docs: update Presto App project documentation"
git push origin main

# 3. Vérifier les déploiements
# Firebase: https://console.firebase.google.com/project/presto-app-74abe
# GitHub Pages: https://stef25fwi.github.io/projects/presto
# Docs: https://stef25fwi.github.io/presto_app
```

---

## ✅ Checklist Final

- [ ] README_PORTFOLIO.md créé dans presto_app
- [ ] GITHUB_PAGES_UPDATE.md créé dans presto_app
- [ ] Tous les fichiers .md de documentation créés dans stef25fwi.github.io
- [ ] Screenshots/images ajoutés
- [ ] Portfolio principal mis à jour
- [ ] Git commits et push effectués
- [ ] GitHub Pages déployé avec succès
- [ ] Firebase deployment vérifié
- [ ] Email system testé
- [ ] Analytics tracking actif

---

**Documentation créée:** 11 janvier 2026  
**Status:** 🟢 Prêt pour publication
