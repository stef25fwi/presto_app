# 📊 Système de Tracking Utilisateurs 10/10

## Vue d'ensemble

Système complet de tracking automatisé avec métriques enrichies, historique de connexions, analytics multi-dimensionnelles et détection nouveau/existant.

---

## ✅ Fonctionnalités implémentées

### 1. **Tracking automatisé** 🤖

Tracking déclenché automatiquement après :
- ✅ Inscription Email
- ✅ Connexion Email
- ✅ Connexion Google (popup + redirect)
- ✅ Connexion Apple

**Aucune action manuelle requise** - tout est automatique !

---

### 2. **Métriques enrichies** 📈

#### Client-Side (Flutter)

**Fonction `_trackLogin()`** avec paramètres optionnels :
```dart
Future<void> _trackLogin({
  String? authMethod,    // 'email' | 'google' | 'apple'
  bool isNewUser = false,
})
```

**Données envoyées** :
- `authMethod` : méthode d'authentification
- `platform` : web | iOS | android | macOS | windows | linux
- `deviceType` : détecté automatiquement
- `isNewUser` : nouveau compte ou existant
- `timestamp` : horodatage précis

**Fichier** : `lib/main.dart:7702-7747`

---

#### Server-Side (Cloud Functions)

**Fonction `trackUserLogin`** enrichie :

**Entrées** :
```javascript
{
  authMethod: 'google',
  platform: 'android',
  deviceType: 'android',
  isNewUser: false,
  timestamp: 1704412800000
}
```

**Actions** :
1. ✅ **Stats globales** (`userStats` document) :
   - `totalLogins` : nombre total de connexions
   - `proLogins` : connexions pro
   - `totalRegistrations` : nouvelles inscriptions
   - `loginsByMethod` : compteurs par méthode
     - `loginsByMethod.email`
     - `loginsByMethod.google`
     - `loginsByMethod.apple`
   - `loginsByPlatform` : compteurs par plateforme
     - `loginsByPlatform.web`
     - `loginsByPlatform.android`
     - `loginsByPlatform.ios`

2. ✅ **Profil utilisateur** (`users/{uid}`) :
   - `lastLoginAt` : dernière connexion
   - `lastSeenAt` : dernière activité
   - `status` : 'online'
   - `lastAuthMethod` : méthode utilisée
   - `lastPlatform` : plateforme
   - `lastDeviceType` : type d'appareil
   - `loginHistory` : 10 dernières connexions

**Fichier** : `functions/index.js:900-985`

---

### 3. **Historique de connexions** 📜

Chaque connexion est enregistrée dans `loginHistory` :

```javascript
{
  timestamp: Timestamp,
  method: 'google',
  platform: 'web',
  deviceType: 'web'
}
```

**Limite** : 10 dernières connexions (auto-nettoyage)

**Utilisation** :
```dart
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

final history = doc.data()?['loginHistory'] as List?;
for (var login in history ?? []) {
  print('${login['method']} via ${login['platform']} le ${login['timestamp']}');
}
```

---

### 4. **Détection nouveau/existant** 🆕

**Logique intelligente** :

1. **Email inscription** → `isNewUser: true`
2. **Email connexion** → `isNewUser: false`
3. **Google/Apple** → vérification Firestore :
   - Si `users/{uid}` n'existe pas → nouveau
   - Si `lastLoginAt` absent → nouveau
   - Sinon → existant

**Code** :
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user?.uid)
    .get();
final isNew = !userDoc.exists || userDoc.data()?['lastLoginAt'] == null;
await _trackLogin(authMethod: 'google', isNewUser: isNew);
```

**Fichiers** :
- Google : `lib/main.dart:8817-8824`
- Apple : `lib/main.dart:8969-8976`

---

### 5. **Stats admin enrichies** 👨‍💼

**Fonction `adminGetUserStats`** retourne :

```javascript
{
  totalAccounts: 1234,           // Total comptes
  onlineUsers: 42,               // En ligne (< 5 min)
  proLogins: 567,                // Connexions pro
  totalRegistrations: 890,       // ✅ NOUVEAU
  loginsByMethod: {              // ✅ NOUVEAU
    email: 450,
    google: 320,
    apple: 120
  },
  loginsByPlatform: {            // ✅ NOUVEAU
    web: 500,
    android: 250,
    ios: 140
  },
  windowMinutes: 5
}
```

**Fichier** : `functions/index.js:998-1038`

---

## 🎯 Cas d'usage

### 1. Analytics dashboard admin

```dart
final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
    .httpsCallable('adminGetUserStats');
final result = await callable.call();

final stats = result.data;
print('Total connexions: ${stats['totalAccounts']}');
print('En ligne: ${stats['onlineUsers']}');
print('Inscriptions: ${stats['totalRegistrations']}');

// Connexions par méthode
final byMethod = stats['loginsByMethod'];
print('Email: ${byMethod['email']}');
print('Google: ${byMethod['google']}');
print('Apple: ${byMethod['apple']}');
```

---

### 2. Profil utilisateur enrichi

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    
    final data = snapshot.data!.data() as Map<String, dynamic>;
    
    return Column(
      children: [
        Text('Dernière connexion: ${data['lastLoginAt']}'),
        Text('Méthode: ${data['lastAuthMethod']}'),
        Text('Plateforme: ${data['lastPlatform']}'),
        Text('Appareil: ${data['lastDeviceType']}'),
        
        // Historique
        ...((data['loginHistory'] as List?) ?? []).map((login) =>
          ListTile(
            title: Text('${login['method']} via ${login['platform']}'),
            subtitle: Text('${login['timestamp']}'),
          )
        ),
      ],
    );
  },
)
```

---

### 3. Graphiques connexions par méthode

```dart
import 'package:fl_chart/fl_chart.dart';

PieChart(
  PieChartData(
    sections: [
      PieChartSectionData(
        value: stats['loginsByMethod']['email'].toDouble(),
        title: 'Email',
        color: Colors.blue,
      ),
      PieChartSectionData(
        value: stats['loginsByMethod']['google'].toDouble(),
        title: 'Google',
        color: Colors.red,
      ),
      PieChartSectionData(
        value: stats['loginsByMethod']['apple'].toDouble(),
        title: 'Apple',
        color: Colors.black,
      ),
    ],
  ),
)
```

---

## 📊 Champs Firestore

### Document `userStats`

```javascript
{
  totalLogins: 5432,
  totalRegistrations: 1234,
  proLogins: 890,
  updatedAt: Timestamp,
  
  loginsByMethod: {
    email: 2100,
    google: 2200,
    apple: 1132
  },
  
  loginsByPlatform: {
    web: 3000,
    android: 1800,
    ios: 632
  }
}
```

---

### Collection `users/{uid}`

```javascript
{
  lastLoginAt: Timestamp,
  lastSeenAt: Timestamp,
  status: 'online',
  
  // ✅ Métriques dernière connexion
  lastAuthMethod: 'google',
  lastPlatform: 'android',
  lastDeviceType: 'android',
  
  // ✅ Historique (10 derniers)
  loginHistory: [
    {
      timestamp: Timestamp,
      method: 'google',
      platform: 'android',
      deviceType: 'android'
    },
    // ... 9 autres
  ]
}
```

---

## 🔥 Optimisations

### 1. Rate limiting
- 10 appels max par minute par utilisateur
- Protection anti-abus

### 2. Best-effort
- Pas d'erreur bloquante si tracking échoue
- Try-catch autour de tous les appels

### 3. Auto-nettoyage historique
- Historique limité à 10 entrées
- Nettoyage asynchrone (non bloquant)

### 4. Batch writes
- `Promise.all` pour stats globales + profil utilisateur
- Réduction latence

---

## 🎓 Appels automatiques

### Après inscription Email
```dart
// lib/main.dart:8292
await _trackLogin(authMethod: 'email', isNewUser: true);
```

### Après connexion Email
```dart
// lib/main.dart:8233
await _trackLogin(authMethod: 'email', isNewUser: false);
```

### Après Google Sign-In
```dart
// lib/main.dart:8824
final isNew = !userDoc.exists || userDoc.data()?['lastLoginAt'] == null;
await _trackLogin(authMethod: 'google', isNewUser: isNew);
```

### Après Google Redirect (Web)
```dart
// lib/main.dart:8189
final isNew = result.additionalUserInfo?.isNewUser ?? false;
await _trackLogin(authMethod: 'google', isNewUser: isNew);
```

### Après Apple Sign-In
```dart
// lib/main.dart:8976
final isNew = !userDoc.exists || userDoc.data()?['lastLoginAt'] == null;
await _trackLogin(authMethod: 'apple', isNewUser: isNew);
```

---

## 🚀 Déploiement

### Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions:trackUserLogin,functions:adminGetUserStats
```

### Flutter
```bash
flutter pub get
flutter run
```

---

## 🔒 Sécurité

- **AppCheck** : activé sur toutes les fonctions
- **Authentification** : `req.auth?.uid` vérifié
- **Rate limiting** : 10/min par utilisateur
- **Admin only** : `adminGetUserStats` vérifie rôle admin

---

## 📈 Métriques disponibles

### Globales
- ✅ Total connexions (`totalLogins`)
- ✅ Connexions pro (`proLogins`)
- ✅ Nouvelles inscriptions (`totalRegistrations`)
- ✅ Utilisateurs en ligne (`onlineUsers`)

### Par méthode
- ✅ Email
- ✅ Google
- ✅ Apple

### Par plateforme
- ✅ Web
- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Windows
- ✅ Linux

### Par utilisateur
- ✅ Dernière méthode
- ✅ Dernière plateforme
- ✅ Dernier appareil
- ✅ Historique 10 connexions

---

## 🎓 Prochaines améliorations possibles

1. **Heatmap horaire** : connexions par heure
2. **Durée de session** : temps moyen passé
3. **Taux de rétention** : users actifs 7j/30j
4. **Geo-localisation** : connexions par pays/ville
5. **Funnel conversion** : inscription → première action
6. **A/B testing** : groupes expérimentaux

---

## 📞 Support

Pour toute question sur le tracking :
- Code client : `lib/main.dart` (lignes 7702-8976)
- Code serveur : `functions/index.js` (lignes 900-1038)

**Système de tracking 10/10 ✅**
