import java.io.FileInputStream
import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// Explicit opt-in for sideload testing; never silently change the release key.
// Flutter forwards --dart-define as an explicit Gradle -Pdart-defines argument.
// Avoid relying on mixed-case ORG_GRADLE_PROJECT_* environment transport on Windows.
val localApkDefine = Base64.getEncoder().encodeToString(
    "LINKBALL_LOCAL_APK=true".toByteArray(Charsets.UTF_8)
)
val localReleaseApk = providers.gradleProperty("dart-defines")
    .map { it.split(",").contains(localApkDefine) }.getOrElse(false) ||
    providers.gradleProperty("linkballLocalApk").map { it == "true" }.getOrElse(false)
val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningProperties = requiredSigningProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val releaseKeystore = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }?.let { file(it) }

// Check the selected task graph so debug builds still work without private keys.
gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter {
        it.project.path == ":app" && it.name.contains("Release", ignoreCase = true)
    }
    if (releaseTasks.isNotEmpty()) {
        if (localReleaseApk) {
            if (releaseTasks.any { it.name.contains("bundle", ignoreCase = true) }) {
                throw GradleException("linkballLocalApk is for local APK testing only. Disable it and configure android/key.properties to build a Play Store AAB.")
            }
            logger.warn("LINKBALL: Local test APK uses the Android debug certificate. Not a Play Store release.")
        } else if (missingSigningProperties.isNotEmpty() || releaseKeystore?.isFile != true) {
            throw GradleException(
                "Linkball release signing is not configured. Restore android/key.properties and its existing keystore. " +
                "Missing properties: ${missingSigningProperties.joinToString().ifEmpty { "none" }}. " +
                "Keystore file exists: ${releaseKeystore?.isFile == true}. " +
                "For a local test APK run: powershell -File tools/build_local_apk.ps1. " +
                "See docs/android-signing.md."
            )
        }
    }
}

android {
    namespace = "com.burakozturk.linkball"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time on old APIs.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.burakozturk.linkball"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        // PHASE 15 App Check environment policy:
        // - Interactive debug/profile builds use Firebase's local debug token.
        // - Android instrumentation running in CI may receive a dedicated token
        //   from the CI secret store. The token value is never committed.
        val appCheckDebugSecret =
            System.getenv("LINKBALL_APP_CHECK_DEBUG_TOKEN")?.trim().orEmpty()
        if (appCheckDebugSecret.isNotEmpty()) {
            testInstrumentationRunnerArguments["firebaseAppCheckDebugSecret"] =
                appCheckDebugSecret
        }
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (missingSigningProperties.isEmpty() && releaseKeystore?.isFile == true) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseKeystore
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (localReleaseApk) "debug" else "release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Pin a current WorkManager runtime for AGP 9/R8 release builds.
    // Google Mobile Ads pulls WorkManager transitively; older resolved versions
    // can crash during AndroidX Startup while creating WorkDatabase.
    implementation("androidx.work:work-runtime:2.11.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

