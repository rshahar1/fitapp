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

// Release builds run lint's "vital" checks on every plugin module. Lint crashes on some plugin sources
// (NoSuchMethodError in its JavaDoc parser, a lint toolchain bug), so skip them for third-party plugin
// modules only; the app module (:app) keeps its release lint checks.
subprojects {
    if (name != "app") {
        tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
