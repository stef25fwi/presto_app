# ✅ Vérification du Chargement de Profil, Droits Admin et Conversations

**Date**: 21 avril 2026  
**Objectif**: Vérifier que le profil se charge correctement, que les droits admin fonctionnent et que les conversations se chargent

---

## 📊 État Global du Code

### ✅ Code Implémenté et Fonctionnel

#### 1. **Service de Bootstrap du Profil**
- **Fichier**: `lib/services/user_profile_bootstrap_service.dart`
- **Statut**: ✅ Implémenté
- **Fonctionnalités**:
  - Création automatique du document utilisateur après authentification
  - Initialisation avec valeurs par défaut (accountType, favoriteCategories, etc.)
  - Synchronisation email et displayName depuis Firebase Auth

#### 2. **Gestion des Droits Admin**
- **Fichier Principal**: `lib/services/admin_access_resolver.dart`
- **Statut**: ✅ Implémenté avec logique complète
- **Fonctionnalités**:
  - Vérification multi-sources (token, profil Firestore, appel serveur)
  - Gestion des rôles (admin, superadmin, etc.)
  - Fallback et retry automatiques
  - Détection des droits admin validés côté serveur

#### 3. **Service de Conversations**
- **Fichier**: `lib/services/conversation_service.dart`
- **Statut**: ✅ Implémenté
- **Fonctionnalités**:
  - `ensureOfferConversation` - Créer/récupérer conversation
  - `sendMessage` - Envoyer message
  - `markAsRead` - Marquer comme lu
  - Archive/Block/Delete - Gestion complète

#### 4. **Page de Conversations**
- **Fichier**: `lib/pages/messages/conversations_list_page.dart`
- **Statut**: ✅ Implémenté
- **Fonctionnalités**:
  - Chargement liste des conversations
  - Filtres (All, Unread, Archived)
  - Détection admin viewer
  - Logs de débogage pour admin

---

## 🧪 Checklist de Vérification

### PHASE 1: Connexion et Profil

#### Test 1.1: Connexion Google
```
Étapes:
  1. Aller à "Mon compte"
  2. Cliquer "Continuer avec Google"
  3. Sélectionner compte Google
  
Attendu:
  ✅ Popup Google s'ouvre
  ✅ Message "✓ Connecté avec Google"
  ✅ Redirection vers page profil
  
Vérification Console:
  - F12 → Console
  - Pas d'erreurs Firebase Auth
```

#### Test 1.2: Création du Document Profil
```
Actions:
  1. Après connexion Google, vérifier Firestore:
     https://console.firebase.google.com/project/presto-app-74abe/firestore
  
Navigation:
  - Collections → users → [Votre UID]
  
À vérifier:
  ✅ Document utilisateur créé automatiquement
  ✅ Champs présents:
     - uid: [votre UID]
     - email: [votre email]
     - emailVerified: true/false
     - createdAt: timestamp
     - lastLoginAt: timestamp
     - lastAuthMethod: "google"
     - accountType: "Particulier"
     - favoriteCategories: []
     - profileCompleteness: 0.0
```

#### Test 1.3: Remplissage du Profil
```
Étapes:
  1. Aller à la page profil
  2. Remplir:
     - Nom
     - Ville
     - Code postal
     - Téléphone
     - Catégories favorites
  3. Cliquer "Sauvegarder"
  
Attendu:
  ✅ Message de succès
  ✅ Les données sont sauvegardées dans Firestore
  ✅ profileCompleteness se met à jour
  
Vérification Firestore:
  - Collections → users → [Votre UID]
  - Vérifier que les champs sont mis à jour
```

---

### PHASE 2: Droits Admin

#### Test 2.1: Détection des Droits Admin (Utilisateur Normal)
```
Étapes:
  1. Connectez-vous avec un compte normal (non-admin)
  2. Ouvrir DevTools (F12)
  3. Vérifier dans la console
  
À vérifier:
  ✅ AdminAccessState s'initialise
  ✅ effectiveIsAdmin = false
  ✅ Aucun message d'erreur
  
Debug:
  - Lancer: flutter run -d chrome --dart-define=DEBUG_ADMIN=true
  - Vérifier les logs admin dans la console
```

#### Test 2.2: Accès à l'Espace Admin
```
Avant: Devez avoir un compte admin configuré dans Firebase
  (Custom Claims avec role: "admin" ou "superadmin")

Étapes pour Configurer (Admin):
  1. Aller à Firebase Console → Custom Claims
  2. Ajouter role: ["admin"] à un utilisateur
  3. Redémarrer l'app ou forcer refresh token

Étapes de Test:
  1. Se connecter avec compte admin
  2. Une option "Espace Admin" apparaît
  
À vérifier:
  ✅ Accès à l'espace admin
  ✅ Pas d'erreurs 403/401
  ✅ Droits admin détectés correctement
  
Logs Détaillés:
  - F12 → Console
  - Chercher "[AdminResolver]"
```

#### Test 2.3: Sources de Vérification des Droits
```
Le système vérifie 3 sources:

1. **Token Claims**
   - Firebase ID Token
   - Claims personnalisés
   
2. **Profil Firestore**
   - users/[uid]/roles
   - users/[uid]/admin
   
3. **Appel Serveur**
   - Fonction Firebase: getMyAdminAccessStatus
   - Vérification côté backend

À vérifier dans Logs:
  [AdminResolver] Stage progression:
    - start
    - auth-user-resolved
    - token-loaded
    - token-has-admin: true/false
    - profile-loaded
    - profile-has-admin: true/false
    - server-check (optionnel)
    - finalized
```

---

### PHASE 3: Conversations

#### Test 3.1: Chargement de la Liste des Conversations
```
Prérequis:
  - 2 comptes créés
  - Au moins 1 offre créée

Étapes:
  1. Aller à "Mes messages"
  2. La liste des conversations charge
  
À vérifier:
  ✅ Liste des conversations s'affiche
  ✅ Pas d'erreur de chargement
  ✅ Conversations groupées par état (active/archive)
  ✅ Compteur de messages non lus
  
Performance:
  - F12 → Network
  - Vérifier qu'une seule requête Firestore
  - Temps < 2 secondes
```

#### Test 3.2: Créer une Conversation via Offre
```
Prérequis:
  - 2 comptes créés
  - Offre visible sur le profil du compte A

Étapes:
  1. Compte A crée une offre
  2. Compte B recherche l'offre
  3. Compte B clique "Contacter"
  4. Conversation créée automatiquement
  
À vérifier:
  ✅ Conversation crée automatiquement
  ✅ Conversation répertoriée dans "Mes messages" des 2 comptes
  ✅ ID conversation valide
  ✅ Participants corrects
  
Vérification Firestore:
  - Collections → conversations
  - Chercher la conversation par ID
  - Vérifier participants, messages, timestamps
```

#### Test 3.3: Envoyer un Message
```
Étapes:
  1. Ouvrir une conversation
  2. Taper un message
  3. Cliquer "Envoyer"
  
À vérifier:
  ✅ Message s'affiche immédiatement
  ✅ Message sauvegardé dans Firestore
  ✅ lastMessageAt mis à jour
  ✅ Timestamp correct
  
Erreurs Possibles:
  - Timeout (> 20 secondes)
  - "Conversation introuvable"
  - Erreurs réseau
```

#### Test 3.4: Marquer comme Lu
```
Étapes:
  1. Ouvrir une conversation non lue
  2. La conversation se marque comme lue
  
À vérifier:
  ✅ Badge "non lu" disparaît
  ✅ lastReadAt mis à jour dans Firestore
  ✅ API "markConversationRead" appelée
```

#### Test 3.5: Archive/Block/Delete
```
Étapes - Archive:
  1. Dans la liste, swipe la conversation vers la gauche
  2. Cliquer "Archive"
  
Attendu:
  ✅ Conversation disparaît de la liste
  ✅ Réapparaît dans le filtre "Archived"
  ✅ isArchived = true dans Firestore

Étapes - Block:
  1. Conversation bloquée
  2. Plus de messages possibles
  
Attendu:
  ✅ isBlocked = true dans Firestore

Étapes - Delete:
  1. Conversation supprimée
  
Attendu:
  ✅ Conversation supprimée de Firestore
  ✅ Disparaît de la liste
```

---

## 🔍 Logs et Débogage

### Activer Logs Détaillés
```dart
// Dans main.dart ou au démarrage
firebase.app?.debugLoggingEnabled = true;
FirebaseAuth.instance.userChanges().listen((user) {
  print('[AUTH] User changed: ${user?.email}');
});
```

### Vérifier dans la Console Navigateur
```javascript
// F12 → Console

// Logs Firebase Auth
"[Google Auth]"

// Logs AdminResolver
"[AdminResolver]"

// Logs ConversationService
"[Conversation]"
```

### Logs Firestore
```
Firebase Console → Logs → Firestore
- Chercher les requêtes "users", "conversations"
- Vérifier les latences
- Vérifier les erreurs d'accès
```

---

## ⚠️ Problèmes Courants et Solutions

### Profil Non Créé
```
Symptôme: Document utilisateur non présent dans Firestore après connexion

Cause Possible:
  1. Fonction Firebase "ensureUserDocument" non exécutée
  2. Erreur lors de la création
  3. Permissions Firestore insuffisantes

Solution:
  1. Vérifier les logs Firestore:
     https://console.firebase.google.com/project/presto-app-74abe/firestore/documents
  2. Vérifier les règles de sécurité:
     https://console.firebase.google.com/project/presto-app-74abe/firestore/rules
  3. Vérifier que l'utilisateur a les droits d'écriture
```

### Droits Admin Non Détectés
```
Symptôme: effectiveIsAdmin = false même avec admin dans le token

Cause Possible:
  1. Token Claims non rafraîchi
  2. Appel serveur échoué
  3. Profil Firestore ne contient pas les droits

Solution:
  1. Forcer rafraîchissement: user.getIdTokenResult(true)
  2. Vérifier les Custom Claims:
     https://console.firebase.google.com/project/presto-app-74abe/authentication/users
  3. Vérifier l'appel serveur:
     - F12 → Network
     - Chercher "getMyAdminAccessStatus"
     - Vérifier la réponse
```

### Conversations Non Chargées
```
Symptôme: Liste des conversations vide ou timeout

Cause Possible:
  1. Pas de conversations existantes
  2. Erreur de requête Firestore
  3. Permissions insuffisantes

Solution:
  1. Vérifier qu'une conversation existe:
     https://console.firebase.google.com/project/presto-app-74abe/firestore/data/conversations
  2. Vérifier les règles de sécurité
  3. Vérifier les logs réseau (F12 → Network)
```

### Message Non Envoyé
```
Symptôme: "Conversation introuvable" ou timeout

Cause Possible:
  1. ensureOfferConversation échoue
  2. Timeout réseau
  3. Permissions insuffisantes

Solution:
  1. Vérifier la conversation existe
  2. Vérifier les logs serveur:
     https://console.firebase.google.com/project/presto-app-74abe/functions/logs
  3. Vérifier timeout (20 secondes par défaut)
```

---

## 📈 Performance

### Cibles Idéales
```
Chargement Profil:
  ✅ < 2 secondes (première connexion)
  ✅ < 500ms (reconnexion)

Chargement Conversations:
  ✅ < 3 secondes (première charge)
  ✅ < 1 seconde (actualisations)

Envoi Message:
  ✅ < 2 secondes
  ✅ Affichage immédiat en local
```

### Comment Mesurer
```
F12 → Network → Filter "conversations"
- Voir la durée des requêtes
- Vérifier les tailles des réponses

F12 → Performance → Enregistrer
- Voir le temps de rendu
- Identifier les goulots
```

---

## ✅ Checklist Finale

```
Profil:
  ☐ Connexion Google OK
  ☐ Document utilisateur créé automatiquement
  ☐ Champs profil sauvegardés
  ☐ Email validé
  ☐ profileCompleteness se met à jour

Droits Admin:
  ☐ Utilisateur normal: effectiveIsAdmin = false
  ☐ Admin détecté correctement (si admin)
  ☐ Pas d'erreurs 403/401
  ☐ Espace Admin accessible (pour admin)
  ☐ Logs [AdminResolver] propres

Conversations:
  ☐ Liste conversations charge
  ☐ Conversation créée via offre
  ☐ Message envoyé/reçu
  ☐ Marqué comme lu
  ☐ Archive/Block/Delete fonctionnent
  ☐ Performance acceptable (< 3s)
```

---

## 🚀 Prochaines Étapes

1. **Tester localement** avec `flutter run -d chrome`
2. **Tester en production** sur Firebase Hosting
3. **Monitoring**: Ajouter analytics pour les erreurs
4. **Optimisations** si nécessaire

---

**Dernière mise à jour**: 21 avril 2026
