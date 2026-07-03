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
