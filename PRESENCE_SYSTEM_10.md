# 🟢 Système de Présence 10/10

## Vue d'ensemble

Système complet de tracking de présence utilisateur avec statuts en temps réel, gestion multi-niveaux client/serveur et optimisations performances.

---

## ✅ Fonctionnalités implémentées

### 1. **Client-Side (Flutter)**

#### Tracking automatique
- **Timer périodique** : mise à jour toutes les 2 minutes
- **Lifecycle app** : 
  - `resumed` → statut `online`
  - `paused`/`inactive` → statut `away`
  - `detached`/`hidden` → statut `offline`
- **Throttling intelligent** : évite les mises à jour < 30s (sauf si statut explicite)
- **Stats de session** : durée de la session enregistrée au logout

#### Fichiers modifiés
- `lib/main.dart:723-765` - Fonction `_touchPresence()` avec throttling
- `lib/main.dart:767-783` - Gestion lifecycle `didChangeAppLifecycleState()`
- `lib/main.dart:847-858` - Cleanup au `dispose()` avec statut offline

#### Variables ajoutées
```dart
DateTime? _lastPresenceUpdate;  // Pour throttling
DateTime? _sessionStartTime;    // Pour stats session
```

---

### 2. **Server-Side (Cloud Functions)**

#### Fonction `trackUserLogin`
- Met à jour `lastSeenAt` et `status: 'online'` au login
- Incrémente les compteurs de connexions
- **Fichier** : `functions/index.js:916-936`

#### Fonction `getUserPresenceStatus` ⭐ NOUVEAU
Récupère le statut de présence de plusieurs utilisateurs (max 50)

**Paramètres** :
```javascript
{
  userIds: ['uid1', 'uid2', ...]
}
```

**Retour** :
```javascript
{
  statuses: {
    'uid1': {
      status: 'online',      // 'online' | 'away' | 'offline'
      lastSeen: 1704412800000,
      sessionDuration: 45    // minutes
    },
    'uid2': { ... }
  }
}
```

**Logique des statuts** :
- `online` : lastSeenAt < 5 min ET status explicite = 'online'
- `away` : lastSeenAt < 15 min
- `offline` : sinon

**Fichier** : `functions/index.js:989-1057`

---

### 3. **Utilitaires Dart**

#### Fonction `getUserPresenceStatus()`
```dart
Future<Map<String, dynamic>> getUserPresenceStatus(List<String> userIds) async
```

Appelle la Cloud Function et retourne les statuts.

**Exemple d'utilisation** :
```dart
final statuses = await getUserPresenceStatus(['user123', 'user456']);
final user123Status = statuses['user123']['status']; // 'online'
```

**Fichier** : `lib/main.dart:53-72`

---

#### Widget `UserStatusIndicator` 🎨

Affiche un indicateur visuel de statut (cercle coloré).

```dart
UserStatusIndicator(
  status: 'online',  // 'online' | 'away' | 'offline'
  size: 12,         // taille du cercle
)
```

**Couleurs** :
- 🟢 Vert : online
- 🟠 Orange : away
- ⚪ Gris : offline

**Fichier** : `lib/main.dart:75-111`

---

## 📊 Champs Firestore

### Collection `users/{uid}`

```javascript
{
  lastSeenAt: Timestamp,           // Dernière activité
  status: 'online'|'away'|'offline', // Statut explicite
  lastLoginAt: Timestamp,          // Dernière connexion
  lastSessionDuration: 45,         // Durée dernière session (min)
}
```

---

## 🎯 Cas d'usage

### 1. Afficher le statut d'un utilisateur dans un chat

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return SizedBox();
    
    final data = snapshot.data!.data() as Map<String, dynamic>?;
    final status = data?['status'] ?? 'offline';
    
    return Row(
      children: [
        UserStatusIndicator(status: status),
        SizedBox(width: 8),
        Text(userId),
      ],
    );
  },
)
```

---

### 2. Vérifier si un utilisateur est en ligne

```dart
final statuses = await getUserPresenceStatus([userId]);
final userStatus = statuses[userId];

if (userStatus['status'] == 'online') {
  print('Utilisateur en ligne !');
}
```

---

### 3. Afficher "Vu il y a X minutes"

```dart
final lastSeen = userStatus['lastSeen'] as int?;
if (lastSeen != null) {
  final diff = DateTime.now().millisecondsSinceEpoch - lastSeen;
  final minutes = (diff / 60000).round();
  
  if (minutes < 1) {
    print('En ligne maintenant');
  } else if (minutes < 60) {
    print('Vu il y a $minutes min');
  } else {
    print('Vu il y a ${(minutes / 60).round()}h');
  }
}
```

---

## 🔥 Optimisations

### 1. Throttling (30s)
Évite les écritures Firestore excessives. La fonction `_touchPresence()` ne met à jour que si :
- Plus de 30s depuis la dernière update OU
- Un statut explicite est fourni (`online`, `away`, `offline`)

### 2. Best-effort
Toutes les mises à jour sont en mode "best-effort" :
- Pas d'erreur bloquante si échec
- Try-catch autour de tous les appels Firestore

### 3. Batch Cloud Functions
`getUserPresenceStatus()` permet de récupérer jusqu'à 50 utilisateurs en une seule requête.

---

## 📈 Admin Dashboard

La fonction `adminGetUserStats()` utilise `lastSeenAt` pour calculer les utilisateurs en ligne :

```javascript
// Utilisateurs vus dans les 5 dernières minutes
.where('lastSeenAt', '>=', now - 5min)
```

**Fichier** : `functions/index.js:940-985`

---

## 🚀 Déploiement

### Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions:getUserPresenceStatus
```

### Flutter
```bash
flutter pub get
flutter run
```

---

## 🔒 Sécurité

- **AppCheck** : activé via `enforceAppCheck: ENFORCE_APP_CHECK`
- **Authentification** : `req.auth?.uid` vérifié sur toutes les fonctions
- **Limite** : max 50 utilisateurs par appel `getUserPresenceStatus`

---

## 📝 Notes techniques

### Timer périodique
- Intervalle : 2 minutes
- Annulé au `dispose()` pour éviter les fuites mémoire

### Session tracking
- `_sessionStartTime` enregistré au `initState()`
- Durée calculée et enregistrée au statut `offline`

### Lifecycle states
- `resumed` : app au premier plan
- `paused` : app en arrière-plan (lock screen, home button)
- `inactive` : transition entre états
- `detached`/`hidden` : app fermée

---

## 🎓 Prochaines améliorations possibles

1. **Typing indicator** : "X est en train d'écrire..."
2. **Read receipts** : "Vu à 15h23"
3. **Push notifications** : notifier quand un utilisateur revient en ligne
4. **Heatmap activité** : graphiques des heures d'activité
5. **Geolocalisation** : "En ligne depuis Paris"

---

## 📞 Support

Pour toute question sur le système de présence :
- Voir le code dans `lib/main.dart` (lignes 53-783)
- Voir les Cloud Functions dans `functions/index.js` (lignes 916-1057)

**Système de présence 10/10 ✅**
