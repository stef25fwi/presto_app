allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Google Services plugin pour Firebase
        classpath("com.google.gms:google-services:4.4.1")
        // Firebase Crashlytics Gradle plugin
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.3")
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires every library module to declare a namespace.
// Older plugins (e.g. flutter_app_badger 1.5.0) omit it — inject it
// from the group attribute which mirrors the manifest package attribute.
// Use plugins.withId so this runs when the plugin is applied (not afterEvaluate,
// which fails when evaluationDependsOn has already forced evaluation).
subprojects {
    plugins.withId("com.android.library") {
        (extensions.findByName("android") as? com.android.build.gradle.LibraryExtension)
            ?.apply {
                if (namespace == null) {
                    namespace = project.group.toString()
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
