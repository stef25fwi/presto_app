# Configuration AdMob / AdSense pour Presto App

## 1️⃣ Obtenir vos IDs AdMob / AdSense

### Android & iOS
1. Créez un compte [Google AdMob](https://admob.google.com).
2. Créez une **App** pour Android et une pour iOS.
3. Générez des **Ad Unit IDs** pour les bannières.
4. Récupérez votre **App ID** (format: `ca-app-pub-XXXXXXXXXX~YYYYYYYYYYYYY`).

### Web
1. Inscrivez-vous à [Google AdSense](https://www.google.com/adsense/).
2. Créez un **slot de publicité** (responsive banner).
3. Récupérez le **slot ID** et le code `<script>` AdSense.

---

## 2️⃣ Mettre à jour les configurations

### AndroidManifest.xml
Remplacez `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy` par votre **App ID AdMob**:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXX~YYYYYYYYYYYYY"/>
```
📄 Chemin: `/android/app/src/main/AndroidManifest.xml`

### Info.plist (iOS)
Remplacez la valeur par votre **App ID AdMob**:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXX~YYYYYYYYYYYYY</string>
```
📄 Chemin: `/ios/Runner/Info.plist`

### ad_banner.dart
Remplacez les **Ad Unit IDs** dans la classe `AdConfig`:
```dart
class AdConfig {
  // ====== ANDROID ======
  static const String androidBannerId = 'ca-app-pub-XXXXXXXXXX/1234567890'; // Votre ID

  // ====== iOS ======
  static const String iosBannerId = 'ca-app-pub-XXXXXXXXXX/0987654321'; // Votre ID

  // ====== WEB / AdSense ======
  static const String webAdSlotId = 'ca-app-pub-XXXXXXXXXX'; // Votre slot ID
}
```
📄 Chemin: `/lib/widgets/ad_banner.dart`

---

## 3️⃣ Intégration AdSense pour le Web

Ajoutez le script AdSense dans `/web/index.html` (avant `</body>`):
```html
<!-- Google AdSense -->
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXXXX"
     crossorigin="anonymous"></script>
```

Ensuite, ajouter des blocs `<ins>` aux endroits où vous voulez les annonces:
```html
<ins class="adsbygoogle"
     style="display:block"
     data-ad-client="ca-pub-XXXXXXXXXX"
     data-ad-slot="YYYYYYYYYY"
     data-ad-format="auto"
     data-full-width-responsive="true"></ins>
<script>
     (adsbygoogle = window.adsbygoogle || []).push({});
</script>
```

---

## 4️⃣ Tester avec les IDs de test Google

Les IDs actuels sont des **IDs de test**. Vous verrez des annonces "test" qui ne génèrent pas de revenus.
- **Test est OK** pour le développement et le déploiement bêta.
- **Passez en production** une fois que vous êtes prêt à monétiser.

---

## 5️⃣ Déployer

```bash
# Nettoyez le cache et mettez à jour
flutter clean
flutter pub get

# Build & test
flutter run  # Mobile
flutter run -d chrome  # Web
```

---

## 📊 Métriques importantes

- **Impressions**: nombre d'affichages des annonces.
- **CTR (Click-Through Rate)**: % d'utilisateurs qui cliquent.
- **RPM (Revenue Per Mille)**: revenus pour 1000 impressions.
- **Fill Rate**: % de requêtes ayant reçu une annonce.

**Suivi**: Accédez à [AdMob Console](https://admob.google.com) ou [AdSense Dashboard](https://adsense.google.com).

---

## 🔑 Points clés

✅ Les 3 points implémentés:
1. **Android/iOS**: App ID + Ad Unit IDs configurés.
2. **Web**: Placeholder intégré, AdSense via HTML.
3. **UX**: Styles améliorés, marges cohérentes, gestion des erreurs.

✅ Fréquence: **1 bandeau tous les 8 annonces** (configurable dans `lib/main.dart`).
