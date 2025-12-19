# ⚡ AIDE RAPIDE - Notifications Push

## 🎯 OBJECTIF
Recevoir les notifications de l'app même quand elle est fermée ✅

---

## ⚡ QUICK START (5 min)

### **1. Installer**
```bash
flutter pub get
```

### **2. Configurer Android**
```
1. Firebase Console → Télécharger google-services.json
2. Placer dans: android/app/google-services.json
3. flutter run
```

### **3. Configurer iOS**
```
1. Firebase Console → Télécharger GoogleService-Info.plist
2. Ouvrir ios/Runner.xcworkspace avec Xcode
3. Drag & drop le fichier dans Xcode
4. Ajouter "Push Notifications" capability
5. Uploader les certificats APNs
6. flutter run
```

### **4. Initialiser l'app**
```dart
// Dans main() ou initState():
await NotificationService().initialize();
```

---

## 📁 FICHIERS IMPORTANTS

| Fichier | Raison | Statut |
|---------|--------|--------|
| `lib/services/notification_service.dart` | Service FCM | ✅ Créé |
| `pubspec.yaml` | firebase_messaging ajouté | ✅ Modifié |
| `android/app/google-services.json` | Config Android | ❌ À télécharger |
| `ios/Runner/GoogleService-Info.plist` | Config iOS | ❌ À télécharger |
| `AndroidManifest.xml` | Permissions | ✅ Modifié |

---

## 🧪 TESTER (2 min)

### **Voir le token FCM:**
```bash
flutter logs | grep "FCM Token"
```

### **Envoyer une notification test:**
1. Firebase Console → Messaging → Créer une campagne
2. Remplir titre + message
3. Cliquer "Envoyer à un appareil de test"
4. Coller le token (ex: `eK1Z...`)
5. Cliquer "Envoyer"

### **Vérifier les logs:**
```bash
flutter logs | grep -i notification
```

---

## 🔧 CONFIGURATION FIREBASE CONSOLE

```
1. Aller à https://console.firebase.google.com
2. Sélectionner le projet
3. Aller à Paramètres (roue dentée) → Cloud Messaging
4. Vérifier que c'est activé
5. Pour Android: Copier google-services.json
6. Pour iOS: 
   - Copier GoogleService-Info.plist
   - Uploader certificat/clé APNs
```

---

## 🚨 ERREURS COMMUNES

| Erreur | Raison | Solution |
|--------|--------|----------|
| Permission denied | google-services.json manquant | Télécharger et placer |
| Token vide | Firebase pas initialisé | Vérifier main() |
| App crash | firebase_messaging pas installé | flutter pub get |
| Notifications ne s'affichent pas | Cloud Messaging désactivé | Activer dans Firebase |

---

## 📱 FONCTIONNALITÉS

- ✅ Notifications en background (app fermée)
- ✅ Notifications en foreground (app ouverte)
- ✅ Gestion des clics
- ✅ Abonnement aux topics
- ✅ Token unique par appareil

---

## 📚 DOCUMENTATION COMPLÈTE

- **[NOTIFICATIONS_SETUP.md](NOTIFICATIONS_SETUP.md)** - Configuration détaillée
- **[NOTIFICATIONS_IMPLEMENTATION.md](NOTIFICATIONS_IMPLEMENTATION.md)** - Intégration pas à pas
- **[NOTIFICATIONS_SUMMARY.md](NOTIFICATIONS_SUMMARY.md)** - Résumé complet

---

## 💡 PRO TIPS

```dart
// S'abonner à un topic (notifications de groupe)
await NotificationService().subscribeToTopic('promo');

// Récupérer le token
final token = await NotificationService().getToken();
print('Mon token: $token');

// Logs de débogage
flutter logs
```

---

## ✅ CHECKLIST FINALE

- [ ] `flutter pub get` exécuté
- [ ] google-services.json placé (Android)
- [ ] GoogleService-Info.plist placé (iOS)
- [ ] AndroidManifest.xml a les permissions
- [ ] Gradle Android configuré
- [ ] NotificationService().initialize() appelé
- [ ] Token FCM visible dans les logs
- [ ] Notification test reçue ✅

---

**PRÊT ?** Aller au fichier [NOTIFICATIONS_IMPLEMENTATION.md](NOTIFICATIONS_IMPLEMENTATION.md) pour le guide complet!
