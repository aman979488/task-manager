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
    project.afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            android?.let { ext ->
                try {
                    val method = ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    method.invoke(ext, 36)
                } catch (_: Exception) {
                    try {
                        val method = ext.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                        method.invoke(ext, 36)
                    } catch (_: Exception) {}
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}