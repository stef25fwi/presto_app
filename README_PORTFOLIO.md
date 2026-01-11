# 🎯 Presto App - Plateforme de Services à la Demande

## 📱 Description

**Presto** est une application mobile Flutter complète pour connecter les demandeurs de services (particuliers) avec les prestataires professionnels en France (DOM-TOM inclus).

Plateforme bilingue (FR/EN) avec support multi-régional, intégration IA avancée, et système de modération complet.

## ✨ Fonctionnalités Principales

### 👥 Pour les Utilisateurs
- ✅ **Création d'annonces vocales** - Dictée via micro, transcription IA
- ✅ **Consultation d'offres** - Recherche, filtrage par catégorie/région
- ✅ **Système de messaging** - Chat temps réel avec prestataires
- ✅ **Profil premium** - Avec favoris et alertes notifications
- ✅ **Paiements sécurisés** - Via Stripe

### 🔧 Pour les Prestataires
- ✅ **Profil professionnel** - Avec portefeuille et avis
- ✅ **Répondre aux annonces** - Soumission de devis
- ✅ **Gestion de missions** - Suivi des projets
- ✅ **Système de notation** - Avis et évaluations

### 🛡️ Pour l'Admin
- ✅ **Modération des annonces** - Avec emails de rejet
- ✅ **Gestion des utilisateurs** - Statistiques, permissions
- ✅ **Gestion des messages** - Archivage, suppression
- ✅ **Configuration IA** - Remote Config Micro-IA
- ✅ **Monitoring WebSocket** - Streaming transcription

## 🏗️ Architecture

```
Frontend (Flutter)          Backend (Firebase)
├── lib/
│   ├── pages/             ├── Firestore (database)
│   ├── widgets/           ├── Authentication
│   ├── services/          ├── Cloud Functions
│   ├── constants.dart     ├── Cloud Storage
│   └── main.dart          └── Firebase Hosting

AI/STT                      External Services
├── Google Speech-to-Text   ├── OpenAI (drafting)
├── Whisper (fallback)      ├── Stripe (payments)
└── Micro-IA (streaming)    └── Gmail (emails)
```

## 🚀 Tech Stack

### Frontend
- **Framework:** Flutter 3.x
- **State:** Provider pattern
- **Networking:** Cloud Firestore, Cloud Functions
- **Analytics:** Firebase Analytics

### Backend
- **Database:** Firestore (NoSQL)
- **Auth:** Firebase Auth
- **Functions:** Node.js/TypeScript
- **Storage:** Cloud Storage
- **Hosting:** Firebase Hosting + GitHub Pages

### AI & Services
- **STT:** Google Speech-to-Text, OpenAI Whisper
- **Drafting:** OpenAI GPT
- **Streaming:** Custom WebSocket (Micro-IA)
- **Email:** Gmail + Nodemailer

## 📊 Statistiques

| Métrique | Valeur |
|----------|--------|
| **Pages Flutter** | 20+ |
| **Cloud Functions** | 15+ |
| **Collections Firestore** | 10+ |
| **Index Firestore** | 16 |
| **Lignes de code** | 30,000+ |
| **Utilisateurs** | 1000+ |
| **Annonces actives** | 500+ |

## 🔐 Sécurité

- ✅ Rules Firestore strictes (authentification + autorisation)
- ✅ Validation côté client et serveur
- ✅ Hachage des mots de passe
- ✅ HTTPS forcé
- ✅ Modération du contenu automatisée
- ✅ Crashlytics pour suivi d'erreurs

## 📈 Récents Ajouts (Jan 2026)

### Admin Pages
- **OffersManagementPage** - Gestion complète des annonces
- **MessagesManagementPage** - Gestion des conversations
- **ModerationPage améliorée** - Avec envoi d'emails

### UI Improvements
- **RecordingMicButton** - Bouton avec animations fluides
- Design cohérent Material Design 3
- Support responsive (mobile/tablet/web)

### Backend
- **sendModerationEmail** - Cloud Function pour rejets
- **Email templating** - HTML professionnel
- Intégration Gmail + Nodemailer

## 🎯 Prochaines Étapes

- [ ] Système de notation/avis amélioré
- [ ] Chat vidéo pour consultations
- [ ] Paiements par escrow
- [ ] Analytics avancées (heatmaps)
- [ ] Push notifications en masse
- [ ] Intégration CRM (Pipedrive)

## 📚 Documentation

- [Release Notes Jan 2026](./RELEASE_NOTES_2026_01.md)
- [Firebase Architecture](./FIREBASE_SERVICE_IMPROVEMENTS.md)
- [Firestore Security Rules](./FIRESTORE_SECURITY_RULES.md)
- [Monitoring Guide](./MONITORING_START_HERE.md)

## 🔗 Liens Utiles

- **App Store:** [Presto iOS](https://apps.apple.com/xxx)
- **Google Play:** [Presto Android](https://play.google.com/store/apps/xxx)
- **Website:** [presto-app.fr](https://presto-app.fr)
- **Firebase:** [Console](https://console.firebase.google.com/project/presto-app-74abe)
- **GitHub:** [stef25fwi/presto_app](https://github.com/stef25fwi/presto_app)

## 👨‍💻 Développeur

**Stéphane Sahai**
- GitHub: [@stef25fwi](https://github.com/stef25fwi)
- Portfolio: [stef25fwi.github.io](https://stef25fwi.github.io)
- Email: sahai.stephane@gmail.com

## 📄 License

MIT License - Voir LICENSE.md

---

**Status:** ✅ En production  
**Dernière mise à jour:** 11 janvier 2026  
**Version:** 2.0.0
