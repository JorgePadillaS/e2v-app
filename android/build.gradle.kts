plugins {
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    plugins.withId("com.android.library") {
        if (
            project.file("src/main/kotlin").exists() &&
            !plugins.hasPlugin("org.jetbrains.kotlin.android") &&
            !plugins.hasPlugin("kotlin-android")
        ) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }

        extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
            compileSdk = 36

            sourceSets.named("main") {
                if (project.file("src/main/kotlin").exists()) {
                    kotlin.srcDir("src/main/kotlin")
                }
            }
            sourceSets.named("test") {
                if (project.file("src/test/kotlin").exists()) {
                    kotlin.srcDir("src/test/kotlin")
                }
            }
        }

        afterEvaluate {
            val androidExtension =
                extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            val jvmTarget = when (androidExtension?.compileOptions?.targetCompatibility) {
                JavaVersion.VERSION_1_8 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                JavaVersion.VERSION_11 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }

            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    this.jvmTarget.set(jvmTarget)
                }
            }
        }
    }
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
