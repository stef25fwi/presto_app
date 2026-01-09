# Guide de Déploiement et Test - Système de Modération

## 🚀 Étape 1: Préparation

### Vérifications préalables
```bash
# Vérifier Firebase CLI installé
firebase --version

# Vérifier la configuration Firebase
firebase projects:list

# Vérifier les functions existantes
firebase functions:list
```

### Vérifier les fichiers
```bash
# Vérifier que tous les fichiers sont présents
ls -la lib/pages/admin/moderation_page.dart
ls -la lib/widgets/moderation_badge.dart
ls -la lib/widgets/user_moderation_status.dart
ls -la functions/src/moderation.ts
```

---

## 🔧 Étape 2: Configuration Firebase

### 2.1 Activer les services requis

Dans Firebase Console:
1. **Firestore Database** : Activer (normalement déjà fait)
2. **Cloud Functions** : Activer
3. **Authentification** : Activer (normalement déjà fait)

### 2.2 Configurer les variables d'environnement

**Option A: Ligne de commande**
```bash
cd /workspaces/presto_app

# Récupérer le compte Gmail à utiliser
# Doit avoir 2FA activé pour créer App Password

firebase functions:config:set \
  gmail.user="your-email@gmail.com" \
  gmail.password="your-16-char-app-password"

# Vérifier la configuration
firebase functions:config:get
```

**Option B: Firebase Console**
1. Aller à Functions → Configuration
2. Ajouter les variables dans l'onglet "Configuration"
3. GMAIL_USER et GMAIL_PASSWORD

### 2.3 Créer le compte de modération

**Créer la collection `admins` dans Firestore:**

```javascript
// Firestore Console → Nouveau Document
Collection: admins
Document ID: admins

Contenu:
{
  admins: [
    "userId_of_moderator_1",
    "userId_of_moderator_2"
  ]
}
```

**Récupérer les UIDs des utilisateurs:**
```bash
# Firebase Console → Authentication → Copier l'UID d'un utilisateur
# Remplacer "userId_of_moderator_1" par l'UID réel
```

### 2.4 Mettre à jour les Security Rules

**Dans Firebase Console → Firestore → Rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règles existantes...
    
    // Nouvelle collection notifications
    match /notifications/{docId} {
      // Lire ses propres notifications
      allow read: if request.auth != null && 
                  resource.data.userId == request.auth.uid;
      
      // Cloud Functions écrit les notifications
      allow write: if request.auth != null &&
                   request.auth.uid in get(/databases/$(database)/documents/admins/admins).data.admins;
    }
    
    // Modération des offers
    match /offers/{offerId} {
      allow read: if true; // Public read
      allow write: if request.auth != null && 
                   request.auth.uid == resource.data.userId;
      
      // Admins peuvent modifier le statut de modération
      allow update: if request.auth != null &&
                    request.auth.uid in get(/databases/$(database)/documents/admins/admins).data.admins;
    }
  }
}
```

---

## 📦 Étape 3: Déploiement Cloud Functions

### 3.1 Vérifier la configuration TypeScript

```bash
cd /workspaces/presto_app/functions

# Vérifier que la config est correcte
cat .runtimeconfig.json

# Vérifier qu'il n'y a pas d'erreurs TypeScript
npm run build
```

### 3.2 Déployer les fonctions

```bash
# Option A: Déployer seulement les fonctions de modération
firebase deploy --only functions:sendModerationWarningEmail,createModerationMessage,logModerationStats

# Option B: Déployer toutes les functions (plus long)
firebase deploy --only functions

# Vérifier le déploiement
firebase functions:list
```

### 3.3 Vérifier les logs

```bash
# Voir les logs en temps réel
firebase functions:log --limit 50

# Chercher des erreurs
firebase functions:log --limit 100 | grep -i error
```

---

## 🧪 Étape 4: Tests

### 4.1 Test de publication d'annonce

1. **Lancer l'app**
   ```bash
   flutter run
   ```

2. **Se connecter** avec un compte test

3. **Publier une annonce**
   - Remplir tous les champs
   - Cliquer "Publier l'offre"
   - **Attendu:** Message "Offre en attente de validation ⏳"

4. **Vérifier dans Firestore**
   ```javascript
   // Firestore Console → offers collection
   // Chercher l'offre créée
   // Vérifier:
   // - status = "pending_moderation"
   // - visibility.isPublic = false
   // - moderation.status = "PENDING"
   ```

5. **Vérifier le badge**
   - Aller dans "Mes annonces publiées"
   - Badge orange "Attente de validation" doit s'afficher

### 4.2 Test de modération

1. **Se connecter comme admin**
   - Utiliser un compte de modérateur

2. **Naviguer vers ModerationPage**
   - Accueil → Mon compte (profil icon)
   - Account → Admin (en haut)
   - Tuile "Modération" → "Validation annonces"

3. **Vérifier les stats**
   - Card "En attente" doit afficher le nombre correct
   - Card "Rejetées" doit afficher 0 (ou le nombre existant)

4. **Test d'approbation**
   - Cliquer "Approuver" sur une annonce
   - **Attendu:** 
     - Annonce disparaît de la liste
     - Firestore: moderation.status = "APPROVED"
     - Firestore: visibility.isPublic = true
     - Stats mise à jour en temps réel

5. **Test de rejet**
   - Cliquer "Rejeter" sur une annonce
   - Dialog s'affiche pour entrer la raison
   - Entrer la raison (ex: "Contenu inapproprié")
   - Cliquer "Rejeter"
   - **Attendu:**
     - Annonce disparaît de la liste "En attente"
     - Annonce apparaît dans "Rejetées"
     - Firestore: moderation.status = "REJECTED"
     - Cloud Functions se déclenchent

### 4.3 Test des notifications

**Vérifier l'email:**
1. Aller dans la boîte mail du compte test
2. **Attendu:** Email reçu de `GMAIL_USER`
   - Sujet: "[iliprestō] Annonce non conforme - [titre]"
   - Contenu: Raison du rejet, conditions d'utilisation, contact

**Vérifier la notification interne:**
1. Se reconnecter avec le compte utilisateur
2. Firestore Console → notifications collection
3. **Attendu:** Document créé
   ```javascript
   {
     userId: "uid_of_user",
     offerId: "id_of_offer",
     type: "MODERATION_WARNING",
     title: "Annonce non conforme",
     message: "[raison entrée par admin]",
     read: false,
     createdAt: Timestamp
   }
   ```

### 4.4 Test du profil

1. Se connecter avec le compte utilisateur
2. Aller sur le profil (Mon compte)
3. **Attendu:** Widget orange "Avertissements de modération"
   - Affiche le nombre d'annonces rejetées
   - Affiche le nombre d'annonces en attente

### 4.5 Test des badges

1. Aller dans "Mes annonces publiées"
2. **Annonces rejetées:** Badge rouge "Rejetée" (avec tooltip raison)
3. **Annonces en attente:** Badge orange "Attente de validation"
4. **Annonces approuvées:** Pas de badge (ou invisible)

---

## 🔍 Troubleshooting

### Problem: Erreur "Permission denied" dans Cloud Functions

**Cause:** L'utilisateur n'est pas admin

**Solution:**
```javascript
// Ajouter l'UID à la collection admins
Firestore → admins/admins → admins array
// Ajouter le UID de l'utilisateur
```

### Problem: Email non reçu

**Checklist:**
- [ ] Variables GMAIL_USER et GMAIL_PASSWORD configurées
- [ ] App Password créé (pas mot de passe principal)
- [ ] 2FA activé sur le compte Gmail
- [ ] Cloud Function déployée sans erreurs
- [ ] Vérifier les logs: `firebase functions:log`
- [ ] Vérifier que l'email utilisateur est correct dans Firestore

### Problem: Badge ne s'affiche pas

**Checklist:**
- [ ] Status field existe dans l'offre
- [ ] Valeur du status est correcte ("pending_moderation", "active")
- [ ] Hot-reload fonctionne (remplacer par rechargement complet)
- [ ] OfferCard importe bien moderation_badge.dart

### Problem: ModerationPage affiche "Aucune annonce en attente"

**Possible:**
- Les annonces n'ont pas le bon format dans Firestore
- Vérifier: `moderation.status` = "PENDING" (case-sensitive!)
- Vérifier la requête Firestore manuellement:
  ```javascript
  db.collection('offers').where('moderation.status', '==', 'PENDING').get()
  ```

---

## 📊 Vérifications des logs

### Logs Cloud Functions

```bash
# Voir tous les logs
firebase functions:log

# Voir seulement les erreurs
firebase functions:log | grep -i error

# Voir les logs d'une fonction spécifique
firebase functions:log --limit 100 | grep sendModerationWarningEmail
```

### Logs Firestore

**Firebase Console → Firestore → Logs**

Chercher:
- Créations dans `notifications`
- Modifications dans `offers.moderation`
- Accès à `admins` collection

---

## ✅ Checklist de validation complète

- [ ] Cloud Functions déployées sans erreurs
- [ ] Variables d'environnement configurées
- [ ] Collection `admins` créée
- [ ] Security Rules mises à jour
- [ ] Annonce publiée → status = pending_moderation
- [ ] Badge orange s'affiche
- [ ] ModerationPage accessible pour admin
- [ ] Approbation fonctionne
- [ ] Rejet crée notification
- [ ] Email reçu
- [ ] Badge rouge s'affiche après rejet
- [ ] Profil affiche avertissements
- [ ] Stats mises à jour en temps réel

---

## 🎯 Commandes rapides

```bash
# Déployer
firebase deploy --only functions:sendModerationWarningEmail,createModerationMessage,logModerationStats

# Voir les fonctions
firebase functions:list

# Voir les logs
firebase functions:log --limit 50

# Tester une fonction
firebase functions:shell
> logModerationStats({})

# Supprimer une fonction (attention!)
firebase functions:delete sendModerationWarningEmail
```

---

## 📞 Support

Si un problème persiste:
1. Vérifier tous les logs (Cloud Functions, Firestore)
2. Vérifier la configuration (variables, rules, admins)
3. Redéployer les fonctions
4. Tester avec un compte neuf
5. Vérifier la documentation: `MODERATION_SYSTEM.md`

---

**Temps estimé:** 30-45 minutes
**Difficulté:** Faible
**Risque:** Très faible (can rollback facilement)
