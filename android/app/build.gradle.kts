import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    // Firebase Crashlytics
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "fr.ilipresto.app"
    // P0 Google Play 2026: valeurs explicites pour rendre le build reproductible
    // et indépendant d'un changement futur des valeurs par défaut de Flutter.
    compileSdk = 36
    // NDK requis par les plugins Firebase (firebase_core 4.x), google_mobile_ads 7
    // et recaptcha_enterprise. Évite l'erreur "depend on a different Android NDK version".
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "fr.ilipresto.app"
        // minSdk 23 : exigé par firebase_core 4.x / firebase_auth 6.x,
        // google_mobile_ads 7.0, recaptcha_enterprise 18.x et record 6.x.
        // (la valeur par défaut flutter.minSdkVersion = 21 ferait échouer le merge du manifest)
        minSdk = flutter.minSdkVersion
        // P0 Google Play 2026: Android 16 / API 36 obligatoire pour les nouvelles
        // applications et mises à jour à compter du 31 août 2026.
        targetSdk = 36
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
                // Lit le type de keystore depuis key.properties (JKS ou PKCS12).
                // Défaut JKS : format généré par generate_keystore.sh (magic FE ED FE ED).
                storeType = keystoreProperties.getProperty("storeType", "JKS")
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
            // Ne bloque pas les builds debug au moment de la configuration Gradle.
            // La vérification stricte est faite plus bas uniquement si une tâche
            // release est réellement demandée.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

val isReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    val normalized = taskName.lowercase()
    normalized.contains("release") || normalized.contains("bundle")
}

if (isReleaseTaskRequested && !rootProject.file("key.properties").exists()) {
    throw GradleException(
        "key.properties introuvable : renseigne android/key.properties pour signer la release"
    )
}

// Built-in Kotlin : le bloc `kotlinOptions {}` (déprécié dans KGP 2.x et supprimé
// avec le Kotlin intégré d'AGP 9) est remplacé par le DSL top-level ci-dessous.
// On aligne la cible JVM de Kotlin sur Java 17 — sinon "Inconsistent JVM-target
// compatibility detected" entre compileXJavaWithJavac (17) et compileXKotlin.
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ── Garde-fou ressources ─────────────────────────────────────────────
// Le « resource merger » d'AGP rejette tout fichier parasite dans res/ :
//   - dans res/values/, seul le .xml est accepté ;
//   - les sauvegardes (strings.xml.bak_..., image.jpg.bak_..., *.orig, etc.)
//     laissées dans res/ font échouer mergeXxxResources.
// Cette tâche les efface AVANT la fusion, pour de bon — quelle que soit
// l'extension d'origine (.xml, .jpg, .png...).
val cleanStrayResFiles by tasks.registering(Delete::class) {
    val resDir = file("src/main/res")
    // Token de sauvegarde (.bak, .bad, .orig…) suivi d'un caractère non alphabétique
    // (underscore, chiffre, point, tiret) ou de la fin du nom — ce qui couvre
    // « strings.xml.bak_fcm_channel_20260619_164831 » et « google-services.json.bad_cli_x.bak ».
    val backupRegex = Regex("""\.(bak|bad|orig|tmp|old|save|swp)([^A-Za-z]|$)|~$""", RegexOption.IGNORE_CASE)
    val stray = resDir.walkTopDown()
        .filter { it.isFile }
        .filter { f ->
            // Toute sauvegarde reconnue, où qu'elle soit sous res/…
            backupRegex.containsMatchIn(f.name) ||
            // …ou tout fichier non-.xml directement dans un dossier values*/
            (f.parentFile?.name?.startsWith("values") == true &&
                !f.name.endsWith(".xml", ignoreCase = true))
        }
        .toList()
    delete(stray)
    doFirst {
        stray.forEach { logger.lifecycle("cleanStrayResFiles: suppression du fichier parasite ${it.relativeTo(rootDir)}") }
    }
}

// Branche le garde-fou sur toutes les tâches de fusion de ressources
// (mergeDebugResources, mergeReleaseResources, mergeProfileResources…).
tasks.matching { it.name.startsWith("merge") && it.name.endsWith("Resources") }
    .configureEach { dependsOn(cleanStrayResFiles) }


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
