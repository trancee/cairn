import java.io.File

plugins {
    id("com.android.kotlin.multiplatform.library")
    kotlin("multiplatform")
    id("ch.ubique.uniffi.plugin")
}
cargo {
    ndkVersion.set("30.0.16248370")
    androidDebugAbis.add("x86_64")
    packageDirectory.set(layout.projectDirectory.dir("rust"))
    targetDirectory.set(
        layout.dir(providers.provider {
            File("/srv/cairn-generator-scratch/unified-cargo-target")
        })
    )
}
uniffi {
    bindgenFromPath(
        layout.dir(providers.provider {
            File("/opt/cairn-binding-seeds/ubique/bindgen")
        }).get()
    )
    generateFromLibrary {
        packageName.set("ch.trancee.cairn.smoke")
    }
}
kotlin {
    android {
        namespace = "ch.trancee.cairn.smoke"
        compileSdk = 37
        minSdk = 26
    }
    jvm()
    jvmToolchain(21)
}
