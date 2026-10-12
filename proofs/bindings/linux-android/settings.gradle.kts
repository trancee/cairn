pluginManagement {
    repositories { google(); mavenCentral() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
val proofPlatform = providers.gradleProperty("cairnProofPlatform").getOrElse("linux-android")
require(proofPlatform == "linux-android" || proofPlatform == "apple") {
    "Unsupported cairnProofPlatform: $proofPlatform"
}
rootProject.name = "cairn-jvm-interop"
include(":sdk", ":consumer")

if (proofPlatform == "apple") {
    require(System.getProperty("os.name") == "Mac OS X") {
        "Apple binding proof requires a macOS host"
    }
    project(":sdk").buildFileName = "apple.gradle.kts"
} else {
    include(":androidConsumer")
}
