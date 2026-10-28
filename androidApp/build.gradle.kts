plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kover)
}

apply(from = rootProject.file("gradle/robolectric.gradle.kts"))

android {
    namespace = "ch.trancee.cairn.android"
    compileSdk = libs.versions.android.compileSdk.get().toInt()
    defaultConfig {
        applicationId = "ch.trancee.cairn.android"
        minSdk = libs.versions.android.minSdk.get().toInt()
        targetSdk = libs.versions.android.compileSdk.get().toInt()
        versionCode = 1
        versionName = "0.1.0"
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

kotlin {
    jvmToolchain(libs.versions.jvm.toolchain.get().toInt())
}

dependencies {
    implementation(project(":androidBle"))
    implementation(libs.androidx.activity.compose)
    implementation(libs.sqldelight.android.driver)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material3)
    debugImplementation(project(":app"))
    testImplementation(libs.junit)
    testImplementation(libs.kotlin.test)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.test.junit4)
    testImplementation(libs.androidx.test.espresso.core)
}

// Constitution T3: Robolectric host tests on API 26 and 37 cover the app in full (ADR 0023 §4).
kover {
    reports {
        filters {
            excludes {
                // The on-device `am instrument` harness, which loads the Rust library a host test cannot.
                classes("ch.trancee.cairn.android.CoreStatusInstrumentation*")
                // Compose-compiler skip/trace branches no test can honestly reach; the UI tests still gate
                // composables, and decisions live in plain code measured at 100% (ADR 0023 §4).
                annotatedBy("androidx.compose.runtime.Composable")
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
