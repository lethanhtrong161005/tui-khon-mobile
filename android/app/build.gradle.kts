import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Opt-in only: normal builds keep their existing package and debug certificate.
val teamMode = System.getenv("TUI_KHON_TEAM") == "1"
val teamDirectory = rootProject.projectDir.parentFile.resolve(".team")
val teamSigning = Properties()
if (teamMode) {
    val signingFile = teamDirectory.resolve("signing.properties")
    require(signingFile.isFile) { "Team setup missing. Run tool/team.ps1 setup -Bundle <private ZIP>." }
    signingFile.inputStream().use { teamSigning.load(it) }
    require(teamDirectory.resolve("team-debug.jks").isFile) { "Team debug keystore missing. Run Team setup again." }
}

android {
    namespace = "com.example.tui_khon_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time on older Android)
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (teamMode) "com.example.tui_khon_mobile.team" else "com.example.tui_khon_mobile"
        manifestPlaceholders["appLabel"] = if (teamMode) "Túi Khôn (Nhóm 5)" else "tui_khon_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (teamMode) {
        signingConfigs.getByName("debug") {
            storeFile = teamDirectory.resolve("team-debug.jks")
            storePassword = teamSigning.getProperty("storePassword")
            keyAlias = teamSigning.getProperty("keyAlias")
            keyPassword = teamSigning.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Team credentials are for internal debug APKs only.
if (teamMode) {
    gradle.taskGraph.whenReady {
        require(allTasks.none { it.project == project && (it.name.contains("Release", true) || it.name.contains("Profile", true)) }) {
            "Team signing supports debug builds only. Use tool/team.ps1 build."
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
