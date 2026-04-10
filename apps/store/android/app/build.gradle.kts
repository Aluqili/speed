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
    var cursor: File? = project.projectDir
    var keyFile: File? = null
    while (cursor != null && keyFile == null) {
        val candidate = File(cursor, "key.properties")
        if (candidate.exists()) {
            keyFile = candidate
        } else {
            cursor = cursor.parentFile
        }
    }
    if (keyFile != null) keyFile.inputStream().use { load(it) }
}

fun signingProp(name: String): String? {
    return keyProperties.getProperty(name)?.trim()
        ?: keyProperties.getProperty("\uFEFF$name")?.trim()
}

val releaseStoreFileValue = localProperties.getProperty("SIGNING_STORE_FILE") ?: signingProp("storeFile")
val releaseStorePassword = localProperties.getProperty("SIGNING_STORE_PASSWORD") ?: signingProp("storePassword")
val releaseKeyAlias = localProperties.getProperty("SIGNING_KEY_ALIAS") ?: signingProp("keyAlias")
val releaseKeyPassword = localProperties.getProperty("SIGNING_KEY_PASSWORD") ?: signingProp("keyPassword")
val normalizedReleaseStorePath = releaseStoreFileValue?.replace('\\', '/')
val releaseStoreFileResolved = if (normalizedReleaseStorePath.isNullOrBlank()) null else File(normalizedReleaseStorePath)
val hasReleaseSigning = !normalizedReleaseStorePath.isNullOrBlank()
    && !releaseStorePassword.isNullOrBlank()
    && !releaseKeyAlias.isNullOrBlank()
    && !releaseKeyPassword.isNullOrBlank()

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
    namespace = "com.aluqili.speedstar.store"
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
            if (!hasReleaseSigning) {
                throw GradleException("Release signing is not configured. Please verify android/key.properties and keystore path.")
            }
            storeFile = releaseStoreFileResolved
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    defaultConfig {
        applicationId = "com.aluqili.speedstar.store"
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
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            manifestPlaceholders["MAPS_API_KEY"] = mapsApiKeyRelease
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
