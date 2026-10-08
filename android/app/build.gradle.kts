import java.util.Properties
import java.io.FileInputStream

// ------------------------------------------------------------
// Snowfall Odyssey — Android app module
// ------------------------------------------------------------
// White slot game + gray WebView portal. See lib/prism/** for
// the gray flow and lib/screens/** for the white game.
// ------------------------------------------------------------

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must apply after Android + Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google Services plugin only once google-services.json is
// present. Keeps QA builds compiling before Firebase credentials ship.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.snowfallodyssey.odysseygame"

    // compileSdk stays 36 for plugin compatibility (gray_part_pitfalls.md §2).
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required by flutter_local_notifications 22+ (java.time.*).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.snowfallodyssey.odysseygame"
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Minify is OFF for now — AppsFlyer / Firebase proguard
            // rules ship in-crate, but Snowfall-specific keep rules
            // belong in app/proguard-rules.pro once we audit the
            // obfuscated binary.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // libprism_core.so is loaded uncompressed straight from the APK
    // via DynamicLibrary.open — matches android:extractNativeLibs="false".
    // Gradle 8+ already defaults useLegacyPackaging=false; set it
    // explicitly so the 16KB page-align build hook never flips it.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
