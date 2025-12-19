# Configuration des Notifications Push - Firebase Cloud Messaging

## 🚀 Installation et Configuration

### 1. Installer les dépendances
```bash
flutter pub get
```

### 2. Configuration Android

#### a) Vérifier que google-services.json est présent
- Le fichier `android/app/google-services.json` doit être présent
- Il contient les configurations Firebase pour Android

#### b) Vérifier la configuration Gradle
Le fichier `android/build.gradle` doit contenir:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

Et `android/app/build.gradle.kts` doit avoir:
```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

#### c) AndroidManifest.xml
Les permissions nécessaires ont été ajoutées:
- `POST_NOTIFICATIONS` (Android 13+)
- `INTERNET`
- `WAKE_LOCK`

### 3. Configuration iOS

#### a) Vérifier que GoogleService-Info.plist est présent
- Le fichier doit être dans `ios/Runner/` ou `ios/Runner/Runner/`

#### b) Ajouter les capacités dans Xcode
1. Ouvrir `ios/Runner.xcworkspace` avec Xcode
2. Sélectionner Runner → Targets → Runner
3. Aller à "Signing & Capabilities"
4. Ajouter la capacité "Push Notifications"

#### c) Configurer le service d'authentification (APNs)
- Dans Firebase Console → Votre projet → Settings → Cloud Messaging
- Uploader le certificat APNs ou créer une clé d'authentification

### 4. Configuration Firebase Console

1. **Créer une collection `fcm_tokens` ou utiliser les profils utilisateurs**

2. **Tester l'envoi de notifications**
   - Firebase Console → Messaging → Créer une campagne
   - Cibler l'application Android/iOS
   - Envoyer à un appareil de test

### 5. Ce qui fonctionne maintenant

✅ **Notifications en foreground** : Quand l'app est ouverte
- Les messages sont affichés en console (logs)
- Peuvent être affichés avec une notification locale

✅ **Notifications en background** : Quand l'app est fermée ou en arrière-plan
- Gérées automatiquement par le système d'exploitation
- Le handler `_firebaseMessagingBackgroundHandler` traite les messages

✅ **Clic sur notification** : Redirection quand l'utilisateur clique
- `FirebaseMessaging.onMessageOpenedApp` détecte le clic

## 🔧 Stockage des tokens FCM

Pour envoyer des notifications ciblées, vous devez stocker le token FCM de chaque utilisateur:

```dart
// Dans Firestore (collection 'users')
{
  'uid': 'user123',
  'email': 'user@example.com',
  'fcmTokens': ['token1', 'token2'], // Peut avoir plusieurs tokens (tablette, phone, etc.)
  ...
}
```

## 📱 Tester localement

### Android
1. Connecter un appareil/émulateur avec Google Play Services
2. Lancer: `flutter run -d <device_id>`
3. Dans Firebase Console → Envoyez une notification de test
4. La notification devrait s'afficher

### iOS
1. Utiliser un appareil physique (Push Notifications ne fonctionne pas sur le simulateur)
2. Configurer un compte Apple Developer
3. Générer et installer les certificats
4. Lancer: `flutter run -d <device_id>`

## 📝 Logs de débogage

Pour vérifier que les notifications fonctionnent:
```
[FCM] Permission status: authorized
[FCM] Token: eK1Z...
[FCM Foreground] Message reçu: ...
[FCM Background] Message reçu: ...
```

## ⚠️ Dépannage

### Les notifications n'arrivent pas
1. Vérifier que `google-services.json` (Android) ou `GoogleService-Info.plist` (iOS) sont présents
2. Vérifier que le projet Firebase Cloud Messaging est activé
3. Vérifier les logs: `flutter logs`
4. S'assurer que l'application a la permission POST_NOTIFICATIONS

### Token FCM vide
- S'assurer que Firebase est correctement initialisé
- Sur Android 6+, vérifier que Google Play Services est installé

### Notifications ne s'affichent pas en background
- Vérifier que le handler `_firebaseMessagingBackgroundHandler` est enregistré
- S'assurer que l'application a les permissions nécessaires

## 📚 Ressources

- [Firebase Messaging Documentation](https://firebase.flutter.dev/docs/messaging/overview)
- [FlutterFire Guide](https://firebase.google.com/docs/flutter/setup)
- [Android Push Notifications](https://developer.android.com/studio/write/vector-asset-studio)
