import com.android.build.gradle.LibraryExtension
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ultrahome_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.ultrahome_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
// ---------------------------------------------------------------
// Для webview_cookie_manager: явно задаём namespace в подпроекте
// ---------------------------------------------------------------
subprojects {
  // ищем плагин по имени
  if (name.contains("webview_cookie_manager")) {
    // как только он применится как library
    plugins.withId("com.android.library") {
      // настраиваем android-расширение
      extensions.configure<LibraryExtension>("android") {
        // Здесь подставьте ваш пакет вместо com.example…
        namespace = "com.example.webview_cookie_manager"
      }
    }
  }
}