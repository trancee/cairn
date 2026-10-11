import java.io.File

plugins {
    kotlin("multiplatform")
    id("ch.ubique.uniffi.plugin")
}
cargo {
    packageDirectory.set(layout.projectDirectory.dir("rust"))
    targetDirectory.set(
        layout.dir(providers.environmentVariable("CARGO_TARGET_DIR").map { File(it) })
    )
}
uniffi {
    bindgenFromPath(
        layout.dir(providers.provider {
            File("/opt/cairn-apple-tools/ubique/bindgen")
        }).get()
    )
    generateFromLibrary {
        packageName.set("ch.trancee.cairn.smoke")
    }
}
kotlin {
    jvm()
    iosArm64()
    iosSimulatorArm64()
    jvmToolchain(21)
}
