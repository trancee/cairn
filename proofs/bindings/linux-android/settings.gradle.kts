pluginManagement {
    repositories { google(); mavenCentral() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "cairn-jvm-interop"
include(":sdk", ":consumer")

include(":androidConsumer")
