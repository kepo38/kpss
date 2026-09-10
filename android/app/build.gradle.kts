import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = sequenceOf(
    file("key.properties"),
    rootProject.file("key.properties"),
).firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.hedefkamu.hedef_kamu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.hedefkamu.hedef_kamu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "ALLOW_SCREENSHOTS", "false")
        // Play Store: emülatör x86_64 yok; kullanıcıya yalnızca telefon ABI.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    signingConfigs {
        val propsFile = keystorePropertiesFile
        if (propsFile != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                    ?: error("key.properties içinde storeFile yok")
                val fromProps = File(storeFilePath)
                storeFile = if (fromProps.isAbsolute) {
                    fromProps
                } else {
                    File(propsFile.parentFile, storeFilePath)
                }
            }
        }
    }

    buildTypes {
        getByName("debug") {
            buildConfigField("boolean", "ALLOW_SCREENSHOTS", "true")
        }
        getByName("profile") {
            buildConfigField("boolean", "ALLOW_SCREENSHOTS", "false")
        }
        release {
            signingConfig = if (keystorePropertiesFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            buildConfigField("boolean", "ALLOW_SCREENSHOTS", "false")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable += "NullSafeMutableLiveData"
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
