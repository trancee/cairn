plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.android.kotlin.multiplatform.library)
}

kotlin {
    jvmToolchain(libs.versions.jvm.toolchain.get().toInt())
    android {
        namespace = "ch.trancee.cairn.app"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()
    }
    // The iOS host app (iosApp/) links this framework; the iOS 15.0 floor is Kotlin/Native's default.
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework { baseName = "CairnApp" }
    }
    sourceSets {
        commonMain.dependencies {
            implementation(project(":sdk"))
        }
    }
}
