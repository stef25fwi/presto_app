# 🔒 Règles de Sécurité Firestore - Documentation

## 📋 Vue d'ensemble

Ce document décrit les règles de sécurité Firestore pour la collection `offers` et les stratégies d'optimisation associées.

---

## 🎯 Collection `offers` - Consultation des offres

### **Lecture publique (READ)**

```javascript
allow read: if isPublicOffer() || isAdmin() || isOwnerByField(resource.data);
```

#### Conditions de lecture:
1. **Offres publiques**: `visibility.isPublic == true` OU `status == 'active'`
2. **Administrateurs**: Utilisateurs dans la collection `/admins` avec `enabled != false`
3. **Propriétaires**: L'utilisateur est le créateur (via `userId`, `uid`, ou `ownerId`)

#### Champs utilisés pour les requêtes:
| Champ | Type | Description | Index requis |
|-------|------|-------------|--------------|
| `category` | String | Catégorie de l'offre | ✅ Composite avec `createdAt` |
| `dept` | String | Code département (ex: "971", "75") | ✅ Composite avec `createdAt` |
| `location` | String | Nom de la ville | ✅ Composite avec `createdAt` |
| `postalCode` | String | Code postal | ✅ Composite avec `createdAt` |
| `subcategory` | String | Sous-catégorie (optionnel) | Simple |
| `createdAt` | Timestamp | Date de création | ✅ Tri descendant |
| `visibility.isPublic` | Boolean | Visibilité publique | Simple |
| `status` | String | Statut legacy ('active') | Simple |

---

## ⚙️ Index Composites Firestore

Les index suivants sont définis dans `firestore.indexes.json`:

### **Index principaux**

1. **Catégorie + Date**
   ```json
   { "category": "ASC", "createdAt": "DESC" }
   ```
   → Permet de filtrer par catégorie tout en triant par date

2. **Département + Date**
   ```json
   { "dept": "ASC", "createdAt": "DESC" }
   ```
   → Filtrage géographique départemental avec tri

3. **Ville + Date**
   ```json
   { "location": "ASC", "createdAt": "DESC" }
   ```
   → Recherche par ville précise

4. **Code Postal + Date**
   ```json
   { "postalCode": "ASC", "createdAt": "DESC" }
   ```
   → Recherche par CP exact

### **Index combinés**

5. **Catégorie + Département + Date**
   ```json
   { "category": "ASC", "dept": "ASC", "createdAt": "DESC" }
   ```

6. **Catégorie + Ville + Date**
   ```json
   { "category": "ASC", "location": "ASC", "createdAt": "DESC" }
   ```

7. **Département + Ville + Date**
   ```json
   { "dept": "ASC", "location": "ASC", "createdAt": "DESC" }
   ```

8. **Catégorie + Département + Ville + Date**
   ```json
   { "category": "ASC", "dept": "ASC", "location": "ASC", "createdAt": "DESC" }
   ```

---

## 🔍 Stratégie de Filtrage Hybride

### **Côté Serveur (Firestore)**
- Filtres structurés: `category`, `dept`, `location`, `postalCode`, `subcategory`
- Tri par `createdAt` (descendant)
- Limite: 100 résultats par requête

### **Côté Client (Dart)**
- Recherche textuelle dans `title` et `description`
- Normalisation intelligente:
  - Suppression diacritiques (é→e, à→a, ç→c)
  - Casse insensible
  - Tokenisation par mots
  - Cache des normalisations (200 entrées max)

**Avantages**:
- Pas besoin d'index full-text Firestore (coûteux)
- Flexibilité maximale pour la recherche
- Performance optimisée avec cache

---

## 📝 Règles d'Écriture (CREATE/UPDATE/DELETE)

### **Création (CREATE)**
```javascript
allow create: if isSignedIn()
  && isOwnerByField(request.resource.data)
  && (!('userId' in request.resource.data) || request.resource.data.userId == uid())
  && (!('uid' in request.resource.data) || request.resource.data.uid == uid())
  && (!('ownerId' in request.resource.data) || request.resource.data.ownerId == uid());
```

**Protection**:
- Utilisateur authentifié obligatoire
- Un des champs `userId`, `uid`, ou `ownerId` doit correspondre à l'UID de l'utilisateur
- Impossible de créer une annonce "au nom" d'un autre utilisateur

### **Mise à jour (UPDATE)**
```javascript
allow update: if isSignedIn()
  && isOwnerByField(resource.data)
  && !('moderation' in request.resource.data)
  && !('visibility' in request.resource.data);
```

**Protection**:
- Seul le propriétaire peut modifier
- Les champs `moderation` et `visibility` sont réservés aux Cloud Functions

### **Suppression (DELETE)**
```javascript
allow delete: if isSignedIn() && isOwnerByField(resource.data);
```

**Protection**:
- Seul le propriétaire peut supprimer son annonce

---

## 🚀 Déploiement des Index

### Commande Firebase CLI
```bash
# Déployer les index depuis firestore.indexes.json
firebase deploy --only firestore:indexes

# Vérifier les index existants
firebase firestore:indexes

# Supprimer les anciens index inutiles
firebase firestore:indexes:delete <INDEX_ID>
```

### Temps de création
- Index simples: ~2-5 minutes
- Index composites: ~5-15 minutes (selon volume de données)
- Plusieurs index en parallèle: ~10-30 minutes

---

## 🧪 Tests de Performance

### Requête sans index (avant):
```dart
// ❌ Erreur si filtres + orderBy sans index
query.where('category', isEqualTo: 'Bricolage')
     .orderBy('createdAt', descending: true);
// → PERMISSION_DENIED: Missing index
```

### Requête avec index (après):
```dart
// ✅ Fonctionne avec firestore.indexes.json déployé
query.where('category', isEqualTo: 'Bricolage')
     .orderBy('createdAt', descending: true)
     .limit(100);
// → ~100-300ms (selon réseau)
```

### Recherche hybride optimisée:
```dart
// 1) Filtres Firestore (serveur)
final snap = await query.where('dept', isEqualTo: '971').get();

// 2) Recherche textuelle (client) avec cache
final normalized = _normalizeText(searchQuery);
final results = snap.docs.where((doc) {
  final title = _normalizeText(doc.data()['title']);
  return title.contains(normalized);
}).toList();
// → ~5-20ms client-side (avec cache)
```

---

## 🔧 Maintenance

### Vérifier les requêtes lentes
```bash
# Console Firebase → Firestore → Usage
# Alertes si latence > 1s
```

### Nettoyer le cache client
```dart
// Dans ConsultOffersPage._ConsultOffersPageState
_normalizedTextCache.clear(); // Reset manuel si besoin
```

### Optimiser les règles
```bash
# Simuler une requête avec Firebase CLI
firebase emulators:start --only firestore
# Puis tester les règles dans l'émulateur
```

---

## 📚 Ressources

- [Documentation Firestore Security Rules](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Guide des Index Composites](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Meilleures pratiques Performance](https://firebase.google.com/docs/firestore/best-practices)

---

**Dernière mise à jour**: 8 janvier 2026  
**Auteur**: Équipe Presto App
