# Système de Modération - Documentation Complète

## Vue d'ensemble

Le système de modération est un ensemble complet permettant de contrôler les annonces publiées par les utilisateurs avant leur publication. Le système fournit :

1. **Badge "Attente de validation"** sur les annonces en modération
2. **Page d'administration** pour les modérateurs
3. **Notifications internes** et **emails** pour les utilisateurs
4. **Affichage du statut** de modération sur le profil utilisateur
5. **Cloud Functions** pour automatiser les notifications et emails

## Architecture du système

### Statuts de modération

Chaque annonce a un champ `status` qui peut avoir les valeurs suivantes :

- `pending_moderation` : Annonce en attente de validation (état initial)
- `active` : Annonce publiée (validée par un modérateur)
- (autres statuts legacy : sera migré progressivement)

Les détails de la modération sont stockés dans le champ `moderation` :

```dart
moderation: {
  status: 'PENDING' | 'APPROVED' | 'REJECTED',
  checkedAt: Timestamp,
  provider: string,
  reason: string,
  userMessage: string,
}
```

### Visibilité

Le champ `visibility` contrôle si l'annonce est publique :

```dart
visibility: {
  isPublic: boolean,
  publishedAt: Timestamp,
}
```

## Composants Flutter

### 1. ModerationBadge Widget

**Fichier:** `lib/widgets/moderation_badge.dart`

Affiche un badge visuel selon le statut de modération.

**Usage:**
```dart
ModerationBadge(
  status: data['status'] ?? 'approved',
  userMessage: data['moderation']?['userMessage'],
)
```

**Affichages:**
- `pending_moderation` : Badge orange avec hourglass "Attente de validation"
- `rejected` : Badge rouge avec close icon "Rejetée" (tooltip avec raison)
- Autres : SizedBox.shrink() (invisible)

### 2. UserModerationStatus Widget

**Fichier:** `lib/widgets/user_moderation_status.dart`

Affiche les avertissements de modération sur le profil utilisateur.

**Usage:**
```dart
UserModerationStatus(userId: user.uid)
```

**Affichage:**
- Container orange avec warning icon si l'utilisateur a des annonces rejetées/en attente
- Affiche le compte de chaque catégorie

### 3. ModerationPage (Admin)

**Fichier:** `lib/pages/admin/moderation_page.dart`

Page d'administration complète pour les modérateurs.

**Fonctionnalités:**
- Affichage des stats (nombre d'annonces en attente, rejetées)
- Liste des annonces en attente de validation
- Liste des annonces rejetées avec raison
- Boutons Approuver/Rejeter pour chaque annonce
- Dialog pour entrer la raison du rejet

**Usage:**
Accès via la tuile "Modération" dans l'Admin Space

## Cloud Functions

**Fichier:** `functions/src/moderation.ts`

### 1. sendModerationWarningEmail

**Déclencheur:** Firestore trigger sur `offers/{offerId}` quand `moderation.status` → `REJECTED`

**Action:** Envoie un email HTML à l'utilisateur avec :
- Titre et détails de l'annonce rejetée
- Raison du rejet
- Lien vers les conditions d'utilisation
- Contact de support

**Environnement:** Nécessite `GMAIL_USER` et `GMAIL_PASSWORD`

### 2. createModerationMessage

**Déclencheur:** Firestore trigger sur `offers/{offerId}` quand `moderation.status` → `REJECTED`

**Action:** Crée un document dans la collection `notifications` avec :
- userId, offerId, type: 'MODERATION_WARNING'
- Message visible dans l'app
- Timestamp de création

### 3. logModerationStats

**Type:** HTTPS callable function

**Authentification:** Admin uniquement (vérifie dans collection `admins`)

**Retour:** JSON avec {pending, rejected, approved}

## Flux de publication d'annonce

1. **Utilisateur publie une annonce** 
   - Les données sont créées avec `status: 'pending_moderation'`
   - `visibility.isPublic: false`
   - `moderation.status: 'PENDING'`
   - Message confirmant: "Offre en attente de validation ⏳"

2. **Badge s'affiche**
   - ModerationBadge dans OfferCard → Orange "Attente de validation"

3. **Modérateur revoit**
   - Admin accède à ModerationPage
   - Voit l'annonce avec tous ses détails

4. **Modérateur approuve**
   - `moderation.status` → `'APPROVED'`
   - `visibility.isPublic` → `true`
   - `status` → `'active'`
   - L'annonce devient visible à tous

5. **Modérateur rejette**
   - Dialog pour entrer la raison
   - `moderation.status` → `'REJECTED'`
   - `status` → `'pending_moderation'`
   - Cloud Functions:
     - Email envoyé à l'utilisateur
     - Notification créée dans Firestore
   - Badge rouge s'affiche sur l'annonce

6. **Utilisateur reçoit les notifications**
   - Badge "Rejetée" sur son annonce
   - Avertissement orange sur son profil
   - Email avec raison du rejet
   - Message interne dans l'app

## Intégrations Dart

### OfferCard Widget

**Fichier:** `lib/widgets/offer_card.dart`

Le badge est intégré après le titre de chaque annonce :

```dart
if (data['status'] != null)
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: ModerationBadge(
      status: data['status'] ?? 'approved',
      userMessage: data['moderation']?['userMessage'],
    ),
  ),
```

### PublishOfferPage

**Fichier:** `lib/pages/publish_offer_page.dart`

Lors de la publication, les données créées incluent :

```dart
'status': 'pending_moderation',
'moderation': {
  'status': 'PENDING',
  'checkedAt': FieldValue.serverTimestamp(),
  'provider': 'system',
},
'visibility': {
  'isPublic': false,
  'publishedAt': null,
},
```

### AccountPage (Profil)

**Fichier:** `lib/profile_page.dart`

Le widget UserModerationStatus est intégré avant la section "Mes annonces publiées" :

```dart
UserModerationStatus(userId: user.uid),
```

## Configuration et Déploiement

### 1. Cloud Functions

Déployer les fonctions :
```bash
cd functions
firebase deploy --only functions:sendModerationWarningEmail,createModerationMessage,logModerationStats
```

### 2. Variables d'environnement

Configurer les variables pour l'email :

```bash
firebase functions:config:set gmail.user="your-email@gmail.com" gmail.password="your-app-password"
```

**Note:** Pour Gmail, créer un "App Password" (nécessite 2FA activé)

### 3. Firestore Security Rules

Ajouter les règles pour la collection `notifications` :

```
match /notifications/{docId} {
  allow read: if request.auth != null && 
              resource.data.userId == request.auth.uid;
  allow write: if request.auth != null &&
               get(/databases/$(database)/documents/admins/$(request.auth.uid)).exists;
}
```

### 4. Admin Collection

Créer la collection `admins` avec les UIDs des modérateurs autorisés.

## Tests

### Test du flux complet

1. **Créer un compte test**
   - Connexion avec email/password

2. **Publier une annonce**
   - Remplir le formulaire
   - Voir le message "Offre en attente de validation ⏳"
   - Badge orange doit s'afficher

3. **Modérer l'annonce** (compte admin)
   - Aller dans Admin → Modération
   - Voir l'annonce en attente
   - Tester Approuver → `visibility.isPublic` doit être true
   - Tester Rejeter → Email et notification doivent être envoyés

4. **Vérifier l'impact utilisateur**
   - Profil : Widget UserModerationStatus doit afficher les violations
   - Mes annonces : Badge "Rejetée" doit s'afficher
   - Email : Devrait être reçu
   - Messages : Notification interne doit apparaître

### Commandes de test

```dart
// Vérifier les annonces en attente
firestore.collection('offers')
  .where('moderation.status', isEqualTo: 'PENDING')
  .get()

// Vérifier les notifications
firestore.collection('notifications')
  .where('userId', isEqualTo: userUid)
  .get()
```

## Constantes et Énumérations

| Élément | Valeur | Description |
|---------|--------|-------------|
| Status | pending_moderation | Annonce en attente (défaut) |
| Status | active | Annonce publiée/approuvée |
| Mod Status | PENDING | En attente de modération |
| Mod Status | APPROVED | Approuvée par modérateur |
| Mod Status | REJECTED | Rejetée par modérateur |
| Notif Type | MODERATION_WARNING | Type de notification de rejet |

## Considérations futures

1. **Auto-modération:** Implémenter une détection automatique de mots interdits
2. **Appels:** Système d'appel/contest des rejets
3. **Audit log:** Tracer toutes les actions de modération
4. **Rate limiting:** Limiter les soumissions fréquentes
5. **SLA:** Temps de modération garanti
6. **Categories:** Règles de modération spécifiques par catégorie
7. **Statistiques:** Dashboard pour suivre les trends de modération

## Fichiers modifiés

- `/lib/widgets/offer_card.dart` : Intégration du badge
- `/lib/profile_page.dart` : Intégration du status widget
- `/lib/pages/publish_offer_page.dart` : Changement du status initial

## Fichiers créés

- `/lib/pages/admin/moderation_page.dart` : Page d'admin
- `/lib/widgets/moderation_badge.dart` : Badge widget
- `/lib/widgets/user_moderation_status.dart` : Status widget
- `/functions/src/moderation.ts` : Cloud Functions

---

**Dernière mise à jour:** 2024
**Statut:** ✅ Production-ready
