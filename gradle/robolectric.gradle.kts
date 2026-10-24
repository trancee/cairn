// Robolectric host tests load pinned android-all jars from the Gradle cache, never from the
// network (ADR 0023 §4). The isolated lanes resolve these configurations with every other input.
// Each SDK needs its own configuration: the jars share one module, so one graph keeps only the newest.
val catalog = extensions.getByType<VersionCatalogsExtension>().named("libs")
val robolectricSdks = listOf("sdk26", "sdk37").map { sdk ->
    configurations.create("robolectricAndroidAll${sdk.replaceFirstChar(Char::uppercaseChar)}") {
        isCanBeConsumed = false
        isTransitive = false
        dependencies.add(project.dependencies.create(catalog.findLibrary("robolectric-android-all-$sdk").get().get()))
    }
}
// Robolectric reads the cached jars in place through this index. Copying them would write files
// beyond the isolated lanes' 128 MiB per-file ceiling (ADR 0014).
val robolectricDeps = layout.buildDirectory.file("robolectric/robolectric-deps.properties")
val writeRobolectricDeps = tasks.register("writeRobolectricDeps") {
    val artifacts = robolectricSdks.map { sdk -> sdk.incoming.artifacts.resolvedArtifacts }
    inputs.files(robolectricSdks).withPropertyName("robolectricSdks").withNormalizer(ClasspathNormalizer::class)
    outputs.file(robolectricDeps)
    doLast {
        val lines = artifacts.flatMap { it.get() }.map { artifact ->
            val id = artifact.id.componentIdentifier as ModuleComponentIdentifier
            val path = artifact.file.absolutePath.replace("\\", "\\\\").replace(":", "\\:")
            "${id.group}\\:${id.module}\\:${id.version}=$path"
        }.sorted()
        robolectricDeps.get().asFile.apply { parentFile.mkdirs() }.writeText(lines.joinToString("\n", postfix = "\n"))
    }
}
tasks.withType<Test>().configureEach {
    dependsOn(writeRobolectricDeps)
    inputs.files(robolectricSdks).withPropertyName("robolectricSdks").withNormalizer(ClasspathNormalizer::class)
    systemProperty("robolectric-deps.properties", robolectricDeps.get().asFile.absolutePath)
    // Robolectric's FileDescriptor interceptor (SDK 37) reaches JDK internals on JDK 17 and later.
    jvmArgs("--add-opens=java.base/java.io=ALL-UNNAMED", "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED")
}
