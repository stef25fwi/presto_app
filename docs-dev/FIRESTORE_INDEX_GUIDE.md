# 🔧 Guide de Résolution des Problèmes Firestore

## 🔴 Problèmes Identifiés

### 1. Index Manquants
Les requêtes Firestore nécessitent des index composites pour :
- **Page d'accueil** : `offers` triés par `createdAt DESC`
- **Page "Je consulte"** : Combinaisons de filtres (`isActive`, `cityId`, `categoryId`, etc.)
- **Messagerie** : `conversations` filtrées par `participants` + triées par `lastMessageAt`

### 2. Erreur de Chargement des Listes
**Symptôme** : "Failed Precondition" ou page vide  
**Cause** : Index Firestore en construction ou manquants

## ✅ Solution : Déploiement des Index

### Étape 1 : Déployer les Index Firestore

```bash
chmod +x deploy_firestore_indexes.sh
./deploy_firestore_indexes.sh
```

Ou manuellement :
```bash
firebase deploy --only firestore:indexes
```

### Étape 2 : Vérifier le Statut des Index

Aller sur la console Firebase :
```
https://console.firebase.google.com/project/presto-app-74abe/firestore/indexes
```

**Statut des index** :
- 🟡 **Building** (en construction) : Patientez 5-10 minutes
- 🟢 **Enabled** (activé) : Prêt à l'emploi
- 🔴 **Error** : Vérifier la configuration

### Étape 3 : Surveiller la Construction

```bash
firebase firestore:indexes
```

## 📊 Index Déployés

### Pour la Collection `offers`

1. **Index de base**
   ```
   isActive (ASC) + createdAt (DESC)
   ```

2. **Index avec ville**
   ```
   isActive (ASC) + cityId (ASC) + createdAt (DESC)
   ```

3. **Index avec catégorie**
   ```
   isActive (ASC) + categoryId (ASC) + createdAt (DESC)
   ```

4. **Index ville+catégorie optimisé**
   ```
   isActive (ASC) + cityCategoryKey (ASC) + createdAt (DESC)
   ```

5. **Index département**
   ```
   isActive (ASC) + dept (ASC) + createdAt (DESC)
   ```

6. **Index sous-catégorie**
   ```
   isActive (ASC) + subcategory (ASC) + createdAt (DESC)
   ```

7. **Index avec budget**
   ```
   isActive (ASC) + budgetValue (ASC) + createdAt (DESC)
   ```

8. **Index page d'accueil (simple)**
   ```
   createdAt (DESC)
   ```

### Pour la Collection `conversations`

```
participants (ARRAY_CONTAINS) + lastMessageAt (DESC)
```

### Pour la Sous-collection `messages`

```
sentAt (ASC)
```

## 🔍 Diagnostic des Erreurs

### Erreur : "Failed Precondition"

**Message complet** :
```
FAILED_PRECONDITION: The query requires an index.
You can create it here: https://console.firebase.google.com/...
```

**Solution** :
1. Copier l'URL fournie dans l'erreur
2. Ouvrir l'URL dans un navigateur
3. Cliquer sur "Create Index"
4. Attendre 5-10 minutes
5. Rafraîchir la page

### Erreur : "Permission Denied"

**Cause** : Règles Firestore trop strictes

**Solution** :
Vérifier [`firestore.rules`](firestore.rules "firestore.rules") :
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /offers/{offerId} {
      // Lecture publique pour toutes les offres actives
      allow read: if resource.data.isActive == true;
      
      // Écriture authentifiée
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
                               request.auth.uid == resource.data.userId;
    }
  }
}
```

Déployer les règles :
```bash
firebase deploy --only firestore:rules
```

## 🚀 Test Après Déploiement

### 1. Vider le Cache du Navigateur

```
Ctrl + Shift + R (Windows/Linux)
Cmd + Shift + R (Mac)
```

### 2. Vérifier la Page d'Accueil

✅ Le carrousel "Dernières offres" doit charger 8 annonces  
✅ Pas d'erreur dans la console (F12)

### 3. Vérifier "Je Consulte"

✅ Liste des offres s'affiche  
✅ Les filtres fonctionnent (ville, catégorie, budget)  
✅ La recherche fonctionne

### 4. Vérifier la Messagerie

✅ Liste des conversations s'affiche  
✅ Envoi/réception de messages en temps réel  
✅ Compteur de messages non lus

## 🛠️ Dépannage Avancé

### Les Index ne se Construisent Pas

1. **Vérifier le quota Firestore** :
   - Console Firebase → Firestore → Usage
   - Limite gratuite : 200 index composites

2. **Supprimer les index inutilisés** :
   ```bash
   firebase firestore:indexes:delete
   ```

3. **Forcer la reconstruction** :
   - Supprimer l'index
   - Redéployer

### Performances Lentes

1. **Ajouter des limites aux requêtes** :
   ```dart
   query = query.limit(20); // Au lieu de charger toute la collection
   ```

2. **Implémenter la pagination** :
   ```dart
   query = query.startAfterDocument(_lastDoc);
   ```

3. **Utiliser le cache local** :
   ```dart
   FirebaseFirestore.instance.settings = const Settings(
     persistenceEnabled: true,
     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
   );
   ```

## 📈 Monitoring

### Logs en Production

Les erreurs Firestore sont automatiquement loggées dans :
- **Console navigateur** (F12)
- **Firebase Crashlytics** : https://console.firebase.google.com/project/presto-app-74abe/crashlytics
- **Firebase Analytics** : https://console.firebase.google.com/project/presto-app-74abe/analytics

### Métriques à Surveiller

- Nombre de lectures Firestore
- Temps de réponse des requêtes
- Taux d'erreur des index
- Utilisation du quota

## ✅ Checklist Post-Déploiement

- [ ] Index déployés (`firebase deploy --only firestore:indexes`)
- [ ] Index construits (statut "Enabled" dans console)
- [ ] Règles Firestore déployées (`firebase deploy --only firestore:rules`)
- [ ] Page d'accueil teste (carrousel charge)
- [ ] Page "Je Consulte" testée (listes s'affichent)
- [ ] Messagerie testée (conversations + envoi)
- [ ] Cache navigateur vidé
- [ ] Tests en navigation privée

## 🔗 Liens Utiles

- [Console Firestore Indexes](https://console.firebase.google.com/project/presto-app-74abe/firestore/indexes)
- [Console Firestore Rules](https://console.firebase.google.com/project/presto-app-74abe/firestore/rules)
- [Documentation Index Composites](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Règles de Sécurité Firestore](https://firebase.google.com/docs/firestore/security/get-started)

## 💡 Bonnes Pratiques

1. **Toujours déployer les index avant le code** qui les utilise
2. **Tester en mode incognito** pour éviter les problèmes de cache
3. **Surveiller les quotas** Firestore (gratuit = 50K lectures/jour)
4. **Limiter les requêtes** avec `.limit()` pour optimiser les coûts
5. **Utiliser le cache local** pour réduire les lectures réseau

---

**Besoin d'aide ?** Vérifiez les logs dans la console Firebase ou ouvrez un ticket GitHub.
