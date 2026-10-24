plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kover)
}

apply(from = rootProject.file("gradle/robolectric.gradle.kts"))

android {
    namespace = "ch.trancee.cairn.ble"
    compileSdk = libs.versions.android.compileSdk.get().toInt()
    defaultConfig {
        minSdk = libs.versions.android.minSdk.get().toInt()
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

kotlin {
    jvmToolchain(libs.versions.jvm.toolchain.get().toInt())
}

dependencies {
    api(project(":sdk"))
    testImplementation(libs.junit)
    testImplementation(libs.kotlin.test)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
}

// Constitution T3: Robolectric host tests on API 26 and 37 cover the radio glue in full (ADR 0023 §4).
kover {
    reports {
        verify {
            rule {
                minBound(100, kotlinx.kover.gradle.plugin.dsl.CoverageUnit.LINE)
                minBound(100, kotlinx.kover.gradle.plugin.dsl.CoverageUnit.BRANCH)
            }
        }
    }
}
