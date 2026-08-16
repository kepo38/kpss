plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.kpss_akademi"
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
        applicationId = "com.example.kpss_odak"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "ALLOW_SCREENSHOTS", "false")
    }

    buildTypes {
        getByName("debug") {
            buildConfigField("boolean", "ALLOW_SCREENSHOTS", "true")
        }
        getByName("profile") {
            buildConfigField("boolean", "ALLOW_SCREENSHOTS", "false")
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            buildConfigField("boolean", "ALLOW_SCREENSHOTS", "false")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable += "NullSafeMutableLiveData"
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
