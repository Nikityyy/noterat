import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kalorat.noterat"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kalorat.noterat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val envKeystorePath = System.getenv("KEYSTORE_PATH")
    val envKeystorePassword = System.getenv("STORE_PASSWORD")
    val envKeyAlias = System.getenv("KEY_ALIAS")
    val envKeyPassword = System.getenv("KEY_PASSWORD")

    val keystorePropertiesFile = rootProject.file("key.properties")

    val hasEnvSecrets = !envKeystorePath.isNullOrEmpty() &&
            !envKeystorePassword.isNullOrEmpty() &&
            !envKeyAlias.isNullOrEmpty() &&
            !envKeyPassword.isNullOrEmpty()

    val hasFileSecrets = keystorePropertiesFile.exists()

    signingConfigs {
        if (hasEnvSecrets || hasFileSecrets) {
            create("release") {
                if (hasEnvSecrets) {
                    storeFile = file(envKeystorePath)
                    storePassword = envKeystorePassword
                    keyAlias = envKeyAlias
                    keyPassword = envKeyPassword
                } else {
                    val keystoreProperties = Properties()
                    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                    storeFile = file(keystoreProperties.getProperty("storeFile") ?: "")
                    storePassword = keystoreProperties.getProperty("storePassword") ?: ""
                    keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
                    keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
                }
            }
        }
    }

    buildTypes {
        release {
            if (hasEnvSecrets || hasFileSecrets) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
