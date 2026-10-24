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
val robolectricSdkDir = layout.buildDirectory.dir("robolectric-sdks")
val syncRobolectricSdks = tasks.register<Sync>("syncRobolectricSdks") {
    from(robolectricSdks)
    into(robolectricSdkDir)
}
tasks.withType<Test>().configureEach {
    dependsOn(syncRobolectricSdks)
    inputs.files(robolectricSdks).withPropertyName("robolectricSdks").withNormalizer(ClasspathNormalizer::class)
    systemProperty("robolectric.offline", "true")
    systemProperty("robolectric.dependency.dir", robolectricSdkDir.get().asFile.absolutePath)
    // Robolectric's FileDescriptor interceptor (SDK 37) reaches JDK internals on JDK 17 and later.
    jvmArgs("--add-opens=java.base/java.io=ALL-UNNAMED", "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED")
}
