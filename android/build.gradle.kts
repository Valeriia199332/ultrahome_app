import com.android.build.gradle.LibraryExtension
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// ------------------------------------------------------------
// Для всех library-модулей, в том числе webview_cookie_manager,
// явно прописываем namespace (AGP 7+ требует его в build-файле)
// ------------------------------------------------------------
pluginManager.withPlugin("com.android.library") {
    extensions.configure<LibraryExtension>("android") {
        // Если это именно webview_cookie_manager — ставим свой namespace
        if (project.name.contains("webview_cookie_manager")) {
            namespace = "com.example.webview_cookie_manager"
        }
    }
}