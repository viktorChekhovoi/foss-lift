allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// androidx.camera 1.6's published API jar carries type annotations on members
// whose types come from concurrent-futures, but does not expose that library as
// an `api` dependency. javac has to resolve those classes to read the
// annotations, so compiling camera_android_camerax fails with
// "CallbackToFutureAdapter not found" unless it is on the compile classpath.
//
// It has to be injected into the plugin's own subproject: declaring it in
// app/build.gradle.kts does nothing, because the failing module is compiled
// separately. Remove this once the camera plugin ships a build that declares it
// itself — the scanner in lib/screens/theme_scan_screen.dart is the only reason
// the camera is here at all.
subprojects {
    if (project.name == "camera_android_camerax") {
        // Deferred until the Android plugin has been applied — the
        // "implementation" configuration does not exist before that.
        project.plugins.withId("com.android.library") {
            project.dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.2.0",
            )
        }
    }
}

// jni 1.0.1 applies the Kotlin plugin only when AGP is older than 9, then calls
// the `kotlin { }` extension unconditionally further down its build file. On AGP
// 9 that extension does not exist, so evaluating `:jni` fails with "Could not
// find method kotlin()" before anything is compiled. Applying the plugin here
// puts the extension back.
//
// jni arrives transitively (flutter_local_notifications 22.2 → jni_flutter →
// jni); nothing in this app calls it directly. Remove this once jni ships a
// build file that applies the plugin for itself.
subprojects {
    if (project.name == "jni") {
        project.plugins.apply("org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
