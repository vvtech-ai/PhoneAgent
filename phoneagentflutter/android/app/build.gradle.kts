plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val inviteEnvironment = System.getenv("PHONEAGENT_ANDROID_ENV") ?: "dev"
require(inviteEnvironment in setOf("dev", "test", "pro")) { "Invalid invitation build environment" }
val debugInviteHost = if (inviteEnvironment == "test") "chakenai-test.vvtech.tech" else "chakenai-dev.vvtech.tech"
val debugInviteScheme = if (inviteEnvironment == "test") "phoneagent-test" else "phoneagent-dev"

android {
    namespace = "com.vvtech.aiassistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    packaging {
        // Vendor packed ELF files must remain byte-identical to the approved SDK.
        jniLibs.keepDebugSymbols += setOf("**/libaliyunaf.so", "**/libfacedevice.so",
            "**/libAPSE_8.0.0.so", "**/libAPSE_J.so", "**/libtoyger.so", "**/libzkfv_tj.so",
            "**/libvvCryptoJni.so", "**/libvvCryptoModuleAndroid.so", "**/libway.so",
            "**/libdataweway.so", "**/libSdkHelper_weway.so", "**/libSdkHelper_weway-x86.so")
    }

    defaultConfig {
        applicationId = "com.vvtech.aiassistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        manifestPlaceholders["inviteHost"] = "chaken.ai"
        manifestPlaceholders["inviteScheme"] = "phoneagent"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
        }
        release {
            // Production signing and legacy-data migration are a later gate.
            signingConfig = null
        }
    }
}

// Flutter 3.32 copies build types into plugin libraries. Set the application
// variant ID directly so applicationIdSuffix cannot leak into library variants.
androidComponents {
    onVariants(selector().all()) { variant ->
        if (variant.buildType == "debug" || variant.buildType == "profile") {
            variant.applicationId.set("com.vvtech.aiassistant.dev")
            variant.manifestPlaceholders.put("inviteHost", debugInviteHost)
            variant.manifestPlaceholders.put("inviteScheme", debugInviteScheme)
        }
    }
}

apply(from = rootProject.file("trusted-caller.gradle"))
apply(from = rootProject.file("test-environment.gradle"))

flutter {
    source = "../.."
}

dependencies {
    // Android-only payment dependency; never registered as a shared Flutter plugin.
    implementation("com.alipay.sdk:alipaysdk-android:15.8.42")
    testImplementation("junit:junit:4.13.2")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation(fileTree("libs/identity") { include("*.aar") })
    implementation(fileTree("libs/trusted_caller") { include("*.aar") })
    implementation(files("libs/trusted_caller/runtime/sdk.jar"))
    implementation("com.google.android.material:material:1.9.0")
    // Same third-party versions as the approved v65 Android SDK integration.
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.alibaba:fastjson:2.0.31")
    // Fixed Android reference: SDK floating identity/avatars call Glide directly.
    implementation("com.github.bumptech.glide:glide:4.15.0")
    annotationProcessor("com.github.bumptech.glide:compiler:4.15.0")
}

gradle.taskGraph.whenReady {
    if (inviteEnvironment == "pro" && allTasks.any {
            it.project == project && (it.name.contains("Debug") || it.name.contains("Profile"))
        }) {
        throw GradleException("Production trusted configuration requires a production release identity.")
    }
    if (System.getenv("PHONEAGENT_ANDROID_ENV") != "test" &&
        allTasks.any { it.project == project && it.name.contains("Release") }) {
        throw GradleException("Foundation is debug-only: production signing and OTA migration are not verified.")
    }
}
