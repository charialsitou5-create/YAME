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

// Le plugin firebase_auth échoue à la compilation Kotlin car son code
// référence des annotations checker-framework absentes de son propre
// classpath ("Type annotation class ... is inaccessible"). On l'ajoute donc
// à tous les sous-projets Android (plugins compris) plutôt qu'au seul module
// app, puisqu'on ne peut pas éditer le build.gradle du plugin lui-même
// (il vit dans le pub-cache et serait écrasé au prochain `flutter pub get`).
subprojects {
    listOf("com.android.library", "com.android.application").forEach { pluginId ->
        pluginManager.withPlugin(pluginId) {
            dependencies.add("implementation", "org.checkerframework:checker-qual:3.42.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
