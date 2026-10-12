plugins {
    id("com.android.application")
}
android {
    namespace = "ch.trancee.cairn.consumer"
    compileSdk = 37
    defaultConfig {
        applicationId = "ch.trancee.cairn.consumer"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
}
kotlin {
    jvmToolchain(21)
}
dependencies {
    implementation(project(":sdk"))
}
