import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

val mapsApiKeyDebug: String = localProperties.getProperty("MAPS_API_KEY_DEBUG")
    ?: (project.findProperty("MAPS_API_KEY_DEBUG") as String?)
    ?: System.getenv("MAPS_API_KEY_DEBUG")
    ?: localProperties.getProperty("MAPS_API_KEY")
    ?: (project.findProperty("MAPS_API_KEY") as String?)
    ?: System.getenv("MAPS_API_KEY")
    ?: ""

val mapsApiKeyRelease: String = localProperties.getProperty("MAPS_API_KEY_RELEASE")
    ?: (project.findProperty("MAPS_API_KEY_RELEASE") as String?)
    ?: System.getenv("MAPS_API_KEY_RELEASE")
    ?: localProperties.getProperty("MAPS_API_KEY")
    ?: (project.findProperty("MAPS_API_KEY") as String?)
    ?: System.getenv("MAPS_API_KEY")
    ?: ""

android {
    namespace = "com.aluqili.speedstar.courier"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            val releaseStoreFile = keyProperties.getProperty("storeFile")
            if (!releaseStoreFile.isNullOrBlank()) {
                storeFile = file(releaseStoreFile)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.aluqili.speedstar.courier"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyDebug
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyDebug
        }
        release {
            signingConfig = if (keyProperties.getProperty("storeFile").isNullOrBlank()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
            manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyRelease
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
