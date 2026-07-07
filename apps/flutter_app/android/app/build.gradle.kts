plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "app.navoiq.flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Matches the iOS bundle ID so Firebase / RevenueCat / analytics can
        // treat both platforms as the same logical app.
        applicationId = "app.navoiq.gameplatform"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Keystore path defaults to ~/keystores/gameplatform-upload.keystore.
            // Password is pulled from the macOS keychain at build time via
            // scripts/build-android-release.sh (sets ANDROID_KEYSTORE_PASSWORD).
            // Falls back gracefully so `flutter run --release` against the
            // debug keystore still works locally for non-distribution builds.
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
                ?: "${System.getProperty("user.home")}/keystores/gameplatform-upload.keystore"
            val pwd = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            if (pwd != null && file(keystorePath).exists()) {
                storeFile = file(keystorePath)
                storePassword = pwd
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "upload"
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: pwd
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config if it was fully populated
            // (i.e. ANDROID_KEYSTORE_PASSWORD env var was set), otherwise
            // fall back to debug signing so `flutter run --release` still works.
            val releaseConfig = signingConfigs.getByName("release")
            signingConfig = if (releaseConfig.storeFile != null) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
