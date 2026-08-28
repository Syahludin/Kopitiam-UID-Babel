allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.configureEach {
        resolutionStrategy {
            force("androidx.concurrent:concurrent-futures:1.2.0")
        }
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

subprojects {
    fun injectFuturesDependency(p: Project) {
        if (p.hasProperty("android")) {
            p.dependencies.add("compileOnly", "androidx.concurrent:concurrent-futures:1.2.0")
            p.dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }

    if (state.executed) {
        injectFuturesDependency(this)
    } else {
        afterEvaluate {
            injectFuturesDependency(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
