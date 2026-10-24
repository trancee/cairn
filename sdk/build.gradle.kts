plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kotlin.multiplatform.library)
    alias(libs.plugins.ubique.uniffi)
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
