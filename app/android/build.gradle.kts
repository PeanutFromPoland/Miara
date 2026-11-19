import java.io.File
import java.security.MessageDigest

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val flutterBuildDir = rootProject.layout.projectDirectory.dir("../build")
val localAppData = providers.environmentVariable("LOCALAPPDATA").orNull
val projectPath = rootProject.projectDir.canonicalFile.toPath()
val isInOneDrive = listOf("OneDrive", "OneDriveCommercial", "OneDriveConsumer")
    .mapNotNull { providers.environmentVariable(it).orNull }
    .any { projectPath.startsWith(File(it).canonicalFile.toPath()) }
val useLocalBuildDir = localAppData != null && isInOneDrive

// Synced directories can become read-only on Windows. Gradle cannot delete
// those directories during cleanMerge*Assets, so keep intermediates outside sync.
val projectKey = MessageDigest.getInstance("SHA-256")
    .digest(projectPath.toString().toByteArray(Charsets.UTF_8))
    .take(8).joinToString("") { "%02x".format(it) }
val newBuildDir = if (useLocalBuildDir) {
    layout.dir(provider { File(localAppData, "Miara/build/$projectKey") }).get()
} else {
    flutterBuildDir
}
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    if (useLocalBuildDir) {
        // Flutter CLI discovers APKs/AABs in app/build. Export only finished
        // packages there; the directories that Gradle cleans stay in LOCALAPPDATA.
        val exportedOutputs = flutterBuildDir.dir("${project.name}/outputs")
        val packageTaskName = Regex("(assemble|bundle).*(Debug|Profile|Release)")
        val packageTasks = tasks.matching {
            it.name == "assemble" || it.name == "bundle" || packageTaskName.matches(it.name)
        }
        val exportTask = tasks.register<Copy>("exportPackagesForFlutter") {
            from(newSubprojectBuildDir.dir("outputs"))
            into(exportedOutputs)
            include("flutter-apk/**", "bundle/**")
            mustRunAfter(packageTasks)
            onlyIf { packageTasks.none { it.state.failure != null } }
        }
        packageTasks.configureEach { finalizedBy(exportTask) }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
