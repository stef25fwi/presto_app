# 🔥 Firebase Service - Architecture Améliorée

## 📋 Vue d'ensemble

Service centralisé pour gérer Firebase avec optimisations de performance, cache, et gestion d'erreurs.

---

## ✨ Améliorations apportées

### 1️⃣ **Service centralisé** ([lib/services/firebase_service.dart](lib/services/firebase_service.dart))

```dart
// ❌ Avant : accès direct partout
FirebaseFirestore.instance.collection('offers').doc(id).get();

// ✅ Après : service centralisé
FirebaseService.instance.getOffer(id);
```

**Avantages**:
- Configuration unique et cohérente
- Gestion d'erreurs centralisée
- Queries optimisées avec cache
- Collections référencées en un point

### 2️⃣ **Persistence et cache**

```dart
// Configuration automatique au démarrage
await FirebaseService.instance.initialize();

// Settings optimisés
firestore.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Performance**:
- Cache illimité activé
- Lecture depuis cache quand disponible
- Synchronisation automatique serveur/cache

### 3️⃣ **Collections typées**

```dart
// Accès simplifié aux collections
final offers = FirebaseService.instance.offersCollection;
final users = FirebaseService.instance.usersCollection;
final convos = FirebaseService.instance.conversationsCollection;
```

### 4️⃣ **Streams optimisés**

```dart
// Stream d'offres avec pagination
final stream = FirebaseService.instance.getOffersStream(
  category: 'Bricolage',
  dept: '971',
  limit: 50,
);

// Stream de conversations
final convos = FirebaseService.instance.getConversationsStream(userId);

// Stream de messages
final msgs = FirebaseService.instance.getMessagesStream(conversationId);
```

### 5️⃣ **Gestion d'erreurs améliorée**

```dart
try {
  await FirebaseService.instance.getOffer(id);
} catch (e) {
  final message = FirebaseService.instance.getErrorMessage(e);
  showErrorSnackBar(context, message);
  
  // Retry si erreur récupérable
  if (FirebaseService.instance.isRecoverableError(e)) {
    // Réessayer...
  }
}
```

**Messages utilisateur**:
- `permission-denied` → "Accès refusé"
- `not-found` → "Document introuvable"
- `unavailable` → "Service indisponible"
- etc.

### 6️⃣ **Batch operations simplifiées**

```dart
await FirebaseService.instance.executeBatch((batch) {
  batch.set(userRef, userData);
  batch.update(offerRef, {'views': FieldValue.increment(1)});
  batch.delete(oldDoc);
});
```

---

## 📚 API Reference

### Propriétés

| Propriété | Type | Description |
|-----------|------|-------------|
| `auth` | `FirebaseAuth` | Instance Firebase Auth |
| `firestore` | `FirebaseFirestore` | Instance Firestore |
| `currentUser` | `User?` | Utilisateur connecté |
| `currentUserId` | `String?` | UID utilisateur |
| `isAuthenticated` | `bool` | État connexion |
| `authStateChanges` | `Stream<User?>` | Stream d'état auth |

### Collections

| Collection | Référence |
|------------|-----------|
| Offers | `offersCollection` |
| Users | `usersCollection` |
| Pros | `prosCollection` |
| Conversations | `conversationsCollection` |
| Messages | `messagesCollection` |
| Notifications | `notificationsCollection` |

### Méthodes principales

#### `initialize()`
Initialise Firebase avec optimisations.

```dart
await FirebaseService.instance.initialize();
```

#### `getOffer(String offerId)`
Récupère une offre (avec cache).

```dart
final snap = await FirebaseService.instance.getOffer('offer123');
if (snap.exists) {
  final data = snap.data()!;
}
```

#### `getOffersStream({...})`
Stream d'offres filtré.

```dart
FirebaseService.instance.getOffersStream(
  category: 'Bricolage',
  dept: '971',
  limit: 100,
).listen((snapshot) {
  final offers = snapshot.docs;
});
```

#### `executeBatch(Function(WriteBatch) operations)`
Exécute plusieurs opérations atomiques.

```dart
await FirebaseService.instance.executeBatch((batch) {
  // Operations...
});
```

#### `getErrorMessage(dynamic error)`
Convertit une erreur Firebase en message utilisateur.

```dart
final userMessage = FirebaseService.instance.getErrorMessage(error);
```

#### `clearCache()`
Vide le cache Firestore (debug).

```dart
await FirebaseService.instance.clearCache();
```

---

## 🚀 Migration progressive

### Étape 1: Nouveau code
Utiliser `FirebaseService.instance` pour tout nouveau code:

```dart
// ✅ Nouveau code
final offers = await FirebaseService.instance.offersCollection
    .where('category', isEqualTo: 'Bricolage')
    .get();
```

### Étape 2: Code existant (optionnel)
Migrer progressivement l'ancien code:

```dart
// ❌ Ancien
FirebaseFirestore.instance.collection('offers')

// ✅ Nouveau
FirebaseService.instance.offersCollection
```

**Note**: L'ancien code continue de fonctionner, pas besoin de tout migrer immédiatement.

---

## 📊 Performance attendue

### Avant
- Lecture réseau: ~200-500ms
- Pas de cache configuré
- Pas de retry automatique

### Après
- Lecture cache: ~5-20ms (si disponible)
- Cache illimité activé
- Gestion erreurs récupérables
- Messages utilisateur clairs

---

## 🔧 Utilisation avancée

### Écouter l'état auth global

```dart
FirebaseService.instance.authStateChanges.listen((user) {
  if (user == null) {
    // Déconnecté
  } else {
    // Connecté: user.uid
  }
});
```

### Query custom avec cache

```dart
final snap = await FirebaseService.instance.offersCollection
    .doc(offerId)
    .get(const GetOptions(source: Source.cache));
```

### Vérifier disponibilité

```dart
if (!FirebaseService.instance.isInitialized) {
  await FirebaseService.instance.initialize();
}
```

---

## 🐛 Debug

### Vider le cache

```dart
// En cas de problème de cache
await FirebaseService.instance.clearCache();
```

### Logs

```dart
// Active automatiquement les logs au démarrage
[FirebaseService] Initialized successfully
[Firestore] Settings configured
[Auth] State changed: abc123...
```

---

## 📝 TODO futur

- [ ] Ajouter retry automatique avec exponential backoff
- [ ] Implémenter offline queue pour writes
- [ ] Métriques de performance (temps de lecture/écriture)
- [ ] Rate limiting côté client
- [ ] Compression des grandes queries

---

**Auteur**: Équipe Presto  
**Date**: 8 janvier 2026  
**Version**: 1.0.0
