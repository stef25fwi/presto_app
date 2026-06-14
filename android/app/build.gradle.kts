import java.util.Properties
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase
    id("com.google.gms.google-services")
    // Firebase Crashlytics
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "fr.ilipresto.app"
    compileSdk = flutter.compileSdkVersion
    // NDK requis par les plugins Firebase (firebase_core 4.x), google_mobile_ads 7
    // et recaptcha_enterprise. Évite l'erreur "depend on a different Android NDK version".
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Aligne la cible JVM de Kotlin sur Java 17 — sinon "Inconsistent JVM-target
    // compatibility detected" entre compileXJavaWithJavac (17) et compileXKotlin.
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }


    defaultConfig {
        applicationId = "fr.ilipresto.app"
        // minSdk 23 : exigé par firebase_core 4.x / firebase_auth 6.x,
        // google_mobile_ads 7.0, recaptcha_enterprise 18.x et record 6.x.
        // (la valeur par défaut flutter.minSdkVersion = 21 ferait échouer le merge du manifest)
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // multidex pour le grand nombre de dépendances Firebase/GMS
        multiDexEnabled = true
    }

    // ── Release Signing ──────────────────────────────────────────────
    // key.properties contient les chemins + mots de passe du keystore.
    // Fichier NON versionné (.gitignore).  Voir key.properties.example.
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "key.properties introuvable : refus de signer un build release avec les clés debug"
                )
            }
        }
    }
}

flutter {
    source = "../.."
}


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
