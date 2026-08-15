# ── Règles R8 minimales ─────────────────────────────────────────────
# Les bibliothèques AndroidX, Kotlin, Firebase et Play Services embarquent
# leurs propres règles consumer-proguard : les sur-keep globaux (`-keep
# class androidx.** { *; }` etc.) neutralisaient R8 et gonflaient l'APK.
# On ne garde ici que ce que les plugins ne déclarent pas eux-mêmes.

# Flutter engine (chargé par réflexion depuis le code natif)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase Crashlytics — conserver les stack traces lisibles
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-renamesourcefileattribute SourceFile

# Google UMP (User Messaging Platform — consentement RGPD), chargé par réflexion
-keep class com.google.android.ump.** { *; }

# reCAPTCHA Enterprise (App Check) — accès par réflexion documenté
-keep class com.google.android.recaptcha.** { *; }
-dontwarn com.google.android.recaptcha.**

# Play Core (split install requis par Flutter deferred components / R8)
-dontwarn com.google.android.play.core.**

# Firebase — le SDK Android instancie plusieurs composants par réflexion, via
# les registrars de composants et l'initialisation par ContentProvider. Les
# règles io.flutter.plugins.** ci-dessus ne couvrent que la couche plugin
# Flutter, pas les classes natives auxquelles elle délègue. Sans ces règles, un
# build minifié peut compiler puis échouer à l'exécution sur l'authentification
# ou les notifications — un défaut invisible en debug, R8 n'y étant pas appliqué.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keepclassmembers class * {
    @com.google.firebase.components.ComponentRegistrar <methods>;
}
-dontwarn com.google.firebase.**

# Modèles sérialisés vers/depuis Firestore : conserver les constructeurs et les
# champs, la désérialisation reposant sur la réflexion.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
