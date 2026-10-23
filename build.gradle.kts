// Raises vulnerable transitive build tooling (AGP, UTP, bundletool) to patched floors.
// Constraints only lift versions already in a graph; they add no dependency and never
// reach published SDK metadata, because consumable configurations are left untouched.
buildscript {
    dependencies {
        constraints {
            libs.bundles.build.tool.floors.get().forEach {
                add("classpath", "${it.group}:${it.name}:${it.version}") {
                    because("patched floor for vulnerable transitive build tooling (ADR 0020)")
                }
            }
        }
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.kotlin.multiplatform.library) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.ubique.uniffi) apply false
}

allprojects {
    val floors = configurations.dependencyScope("cairnBuildToolFloors") {
        libs.bundles.build.tool.floors.get().forEach {
            dependencyConstraints.add(project.dependencies.constraints.create("${it.group}:${it.name}:${it.version}") {
                because("patched floor for vulnerable transitive build tooling (ADR 0020)")
            })
        }
    }
    configurations.configureEach {
        if (isCanBeResolved && !isCanBeConsumed) {
            extendsFrom(floors.get())
        }
    }
}
