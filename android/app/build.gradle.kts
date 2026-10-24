plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aapkelawyer.app.in"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aapkelawyer.app.in"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Keystore file placed at the project root: upload-keystore.jks
            storeFile = rootProject.file("upload-keystore.jks")
            storePassword = (project.findProperty("PLAY_STORE_STORE_PASSWORD") as String?) ?: ""
            keyAlias = (project.findProperty("PLAY_STORE_KEY_ALIAS") as String?) ?: ""
            keyPassword = (project.findProperty("PLAY_STORE_KEY_PASSWORD") as String?) ?: ""
        }
    }

    buildTypes {
        release {
            // Use the release signing config. Fill properties in android/gradle.properties or
            // provide them via Gradle properties when building (recommended to keep secrets out of VCS).
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
