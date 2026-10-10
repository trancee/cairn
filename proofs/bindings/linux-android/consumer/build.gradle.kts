plugins { kotlin("multiplatform") }
kotlin {
    jvm()
    jvmToolchain(21)
    sourceSets {
        jvmMain.dependencies { implementation(project(":sdk")) }
    }
}
val mainCompilation = kotlin.targets.getByName("jvm").compilations.getByName("main")
tasks.register<JavaExec>("interopSmoke") {
    dependsOn(mainCompilation.compileTaskProvider)
    classpath = mainCompilation.output.allOutputs +
        configurations.getByName("jvmRuntimeClasspath")
    mainClass.set("SmokeKt")
    javaLauncher.set(javaToolchains.launcherFor {
        languageVersion.set(JavaLanguageVersion.of(21))
    })
}
