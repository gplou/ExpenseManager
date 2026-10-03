allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance") {
                useVersion("1.1.1")
                because("home_widget requests glance-appwidget:1.+, which now resolves to 1.3.0-alpha02 and requires compileSdk 37 (above what AGP 9.1.0 supports)")
            }
        }
    }
    // Solo las dependencias (no "app", que ya está bien configurado y además
    // Gradle no permite registrar afterEvaluate en él aquí: el
    // evaluationDependsOn(":app") de arriba lo evalúa eager, así que para
    // cuando subprojects{} llega a "app" ya está evaluado y afterEvaluate
    // lanzaria "Cannot run Project.afterEvaluate(Action) when the project is
    // already evaluated").
    if (project.name != "app") {
        afterEvaluate {
            // Algunos plugins (p.ej. posthog_flutter) fijan su propio
            // kotlinOptions.jvmTarget de forma sincrona en su build.gradle: un
            // configureEach sin envolver aqui pierde esa carrera y gana el
            // target (mas antiguo) del plugin, causando "Inconsistent JVM
            // Target Compatibility" contra el compileOptions de Java de abajo.
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                    languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                    apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                }
            }
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                // Algunos plugins (p.ej. flutter_native_splash 2.4.4) fijan su propio
                // compileSdk antiguo y AGP 9 lo trata como error si sus dependencias
                // transitivas (androidx.*) exigen uno más alto. Forzamos el mismo suelo
                // que usa la app para que compilen contra APIs recientes.
                if (compileSdkVersion?.substringAfter('-')?.toIntOrNull()?.let { it < 36 } != false) {
                    compileSdkVersion("android-36")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
