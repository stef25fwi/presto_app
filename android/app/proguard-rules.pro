# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Crashlytics — conserver les stack traces lisibles
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-renamesourcefileattribute SourceFile

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google UMP (User Messaging Platform — consentement RGPD)
-keep class com.google.android.ump.** { *; }

# reCAPTCHA Enterprise (App Check / anti-spam)
-keep class com.google.android.recaptcha.** { *; }
-dontwarn com.google.android.recaptcha.**

# Play Core (split install requis par Flutter deferred components / R8)
-dontwarn com.google.android.play.core.**

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**
