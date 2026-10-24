plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kotlin.multiplatform.library)
    alias(libs.plugins.ubique.uniffi)
    alias(libs.plugins.kover)
}

cargo {
    packageDirectory = rootProject.layout.projectDirectory.dir("core/cairn-ffi")
    ndkVersion = libs.versions.android.ndk
}

uniffi {
    // Isolated build lanes supply a pre-provisioned generator; elsewhere the plugin installs its own.
    providers.gradleProperty("cairn.uniffi.bindgen").orNull?.let { bindgen ->
        bindgenFromPath(layout.projectDirectory.dir(bindgen))
    }
    generateFromLibrary {
        packageName = "ch.trancee.cairn.ffi"
    }
}

kotlin {
    jvmToolchain(libs.versions.jvm.toolchain.get().toInt())
    jvm()
    android {
        namespace = "ch.trancee.cairn.sdk"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()
    }
    // The iOS 15.0 deployment floor is Kotlin/Native's default; the Apple lane verifies it.
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework { baseName = "CairnSdk" }
    }
    sourceSets {
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
    }
}

// Constitution T3: the handwritten SDK keeps full line and branch coverage. Kover measures the JVM
// test run, which executes commonMain; the generated bindings are UniFFI's, not ours.
kover {
    reports {
        filters {
            excludes {
                packages("ch.trancee.cairn.ffi")
            }
        }
        verify {
            rule {
                minBound(100, kotlinx.kover.gradle.plugin.dsl.CoverageUnit.LINE)
                minBound(100, kotlinx.kover.gradle.plugin.dsl.CoverageUnit.BRANCH)
            }
        }
    }
}
