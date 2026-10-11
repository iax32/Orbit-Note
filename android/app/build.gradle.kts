import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

fun signingValue(name: String): String? =
    System.getenv(name)?.trim()?.takeIf { it.isNotEmpty() }
        ?: signingProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val releaseStoreFile = signingValue("ORBIT_ANDROID_STORE_FILE")
    ?: signingProperties.getProperty("storeFile")?.trim()?.takeIf { it.isNotEmpty() }
val releaseStorePassword = signingValue("ORBIT_ANDROID_STORE_PASSWORD")
    ?: signingProperties.getProperty("storePassword")?.trim()?.takeIf { it.isNotEmpty() }
val releaseKeyAlias = signingValue("ORBIT_ANDROID_KEY_ALIAS")
    ?: signingProperties.getProperty("keyAlias")?.trim()?.takeIf { it.isNotEmpty() }
val releaseKeyPassword = signingValue("ORBIT_ANDROID_KEY_PASSWORD")
    ?: signingProperties.getProperty("keyPassword")?.trim()?.takeIf { it.isNotEmpty() }
val requireProductionSigning =
    System.getenv("ORBIT_REQUIRE_PRODUCTION_SIGNING")?.toBoolean() == true

val hasProductionSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

if (requireProductionSigning && !hasProductionSigning) {
    throw GradleException(
        "Production Android signing is required. Configure the ORBIT_ANDROID_* " +
            "secrets or android/key.properties before creating a release.",
    )
}

android {
    namespace = "org.orbitnote.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.orbitnote.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasProductionSigning) {
        signingConfigs {
            create("orbitRelease") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Local release builds may use debug signing for development. The
            // release workflow sets ORBIT_REQUIRE_PRODUCTION_SIGNING and cannot
            // publish unless a real keystore is configured.
            signingConfig = if (hasProductionSigning) {
                signingConfigs.getByName("orbitRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
