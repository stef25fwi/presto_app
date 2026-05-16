# 📌 Guide d'Intégration - Notifications Push

## 1️⃣ Installation des dépendances

```bash
cd /workspaces/presto_app
flutter pub get
```

Ceci téléchargera et installera `firebase_messaging` et toutes les dépendances.

## 2️⃣ Configuration Android

### Étape 1: Obtenir `google-services.json`

1. Aller à [Firebase Console](https://console.firebase.google.com)
2. Sélectionner votre projet
3. Aller à **Paramètres** → **Paramètres du projet** (roue dentée en haut à gauche)
4. Aller à l'onglet **Applications**
5. Cliquer sur l'application Android
6. Télécharger **`google-services.json`**
7. Placer le fichier dans: `android/app/google-services.json`

### Étape 2: Vérifier la configuration

- ✅ `android/build.gradle.kts` - Plugin Google Services ajouté
- ✅ `android/app/build.gradle.kts` - Plugin appliqué
- ✅ `android/app/src/main/AndroidManifest.xml` - Permissions ajoutées

## 3️⃣ Configuration iOS

### Étape 1: Obtenir `GoogleService-Info.plist`

1. Aller à [Firebase Console](https://console.firebase.google.com)
2. Sélectionner votre projet
3. Aller à **Paramètres** → **Paramètres du projet**
4. Aller à l'onglet **Applications**
5. Cliquer sur l'application iOS
6. Télécharger **`GoogleService-Info.plist`**
7. Placer le fichier avec Xcode:
   - Ouvrir `ios/Runner.xcworkspace` avec Xcode (⚠️ pas `.xcodeproj`)
   - Clic droit sur Runner → Add Files to Runner
   - Sélectionner le fichier téléchargé
   - S'assurer que "Copy items if needed" est coché

### Étape 2: Configurer les Push Notifications

1. Ouvrir `ios/Runner.xcworkspace` avec Xcode
2. Sélectionner **Runner** → **Targets** → **Runner**
3. Aller à **Signing & Capabilities**
4. Cliquer sur **+ Capability** (coin supérieur gauche)
5. Chercher et ajouter **"Push Notifications"**

### Étape 3: Configurer APNs

1. Aller à [Apple Developer Account](https://developer.apple.com/account/)
2. Créer/générer les certificats APNs (Apple Push Notification service)
3. Revenir à Firebase Console → Paramètres du projet → Cloud Messaging
4. Cliquer sur **iOS App Configuration**
5. Uploader le certificat ou la clé d'authentification APNs

## 4️⃣ Initialisation dans l'Application

### Option 1: Initialisation dans `initState` (recommandée pour une page)

```dart
@override
void initState() {
  super.initState();
  _initializeNotifications();
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Erreur initialisation notifications: $e');
  }
}
```

### Option 2: Initialisation dans `main()` (pour toute l'app)

Modifier `lib/main.dart`:

```dart
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await CitySearch.instance.ensureLoaded();
  
  // ✨ Initialiser les notifications
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Erreur FCM: $e');
  }

  runApp(const PrestoApp());
}
```

## 5️⃣ Sauvegarder les Tokens FCM dans Firestore

Modifier `lib/services/notification_service.dart` - Fonction `_saveFcmTokenToFirestore()`:

```dart
static Future<void> _saveFcmTokenToFirestore(String token) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Ajouter le token à la liste des tokens de l'utilisateur
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
    
    debugPrint('[Notifications] Token sauvegardé pour ${user.uid}');
  } catch (e) {
    debugPrint('[Notifications] Erreur sauvegarde token: $e');
  }
}
```

## 6️⃣ Tester les Notifications

### Test via Firebase Console

1. Firebase Console → **Engagement** → **Messaging**
2. Cliquer sur **Créer une campagne** → **Notifications**
3. Remplir le titre et le message
4. Cliquer sur **Envoyer à un appareil de test**
5. Entrer le token FCM (voir logs)
6. Cliquer sur **Envoyer**

### Voir les Logs

```bash
flutter logs
```

Chercher les messages:
```
[Notifications] Permission status: authorized
[Notifications] FCM Token: eK1Z...
[Notifications-Background] Message reçu: ...
[Notifications-Foreground] Message reçu: ...
```

## 7️⃣ Redirection selon le Type de Notification

Modifier `_handleMessage()` dans `lib/services/notification_service.dart`:

```dart
static void _handleMessage(RemoteMessage message) {
  final messageData = message.data;
  
  if (messageData.containsKey('type')) {
    final type = messageData['type'];
    
    switch (type) {
      case 'new_message':
        // Rediriger vers Messages
        navigatorKey.currentState?.pushNamed('/messages');
        break;
      case 'offer_update':
        // Rediriger vers Offres
        navigatorKey.currentState?.pushNamed('/offers');
        break;
      case 'offer_accepted':
        // Rediriger vers le détail de l'offre
        final offerId = messageData['offerId'];
        navigatorKey.currentState?.pushNamed('/offer/$offerId');
        break;
    }
  }
}
```

## 🐛 Dépannage

### Problème: "Permission denied for firebase_messaging"
- Vérifier que `google-services.json` (Android) ou `GoogleService-Info.plist` (iOS) sont présents
- Faire `flutter clean && flutter pub get`

### Problème: Token vide
- S'assurer que Firebase est initialisé avant les notifications
- Sur Android 6+, vérifier que Google Play Services est installé
- L'utilisateur doit avoir accepté les permissions

### Problème: Notifications n'arrivent pas
- Vérifier que Cloud Messaging est activé dans Firebase Console
- S'assurer que l'appareil a Internet
- Vérifier les logs: `flutter logs | grep -i fcm`
- Sur iOS: Vérifier que les certificats APNs sont configurés

### Problème: App crash au démarrage
- Vérifier les logs pour les erreurs import
- S'assurer que `firebase_messaging` est bien installé: `flutter pub get`
- Faire `flutter clean` et relancer

## ✅ Checklist de Déploiement

- [ ] `firebase_messaging: ^14.9.4` ajouté à `pubspec.yaml`
- [ ] `flutter pub get` exécuté
- [ ] Android: `google-services.json` placé dans `android/app/`
- [ ] Android: Permissions ajoutées dans `AndroidManifest.xml`
- [ ] iOS: `GoogleService-Info.plist` ajouté via Xcode
- [ ] iOS: Push Notifications capability activée
- [ ] iOS: Certificats APNs configurés
- [ ] `NotificationService().initialize()` appelé dans l'app
- [ ] Tokens FCM sauvegardés dans Firestore
- [ ] Notifications testées via Firebase Console
- [ ] Redirection implémentée pour chaque type
