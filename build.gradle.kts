// Raises vulnerable transitive build tooling (AGP, UTP, bundletool, Kover, KGP) to patched floors.
// Constraints only lift versions already in a graph and add no dependency. Every resolvable
// configuration gets them, including AGP's legacy lint and UTP ones, which are also
// consumable. Consumable-only variants, which publishing would use, stay untouched.
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
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.android.kotlin.multiplatform.library) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kover) apply false
    alias(libs.plugins.sqldelight) apply false
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
        if (isCanBeResolved) {
            extendsFrom(floors.get())
        }
    }
}
