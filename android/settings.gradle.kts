pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

// ffmpeg-kit 原版 Maven 制品 2025-04 起已从 Maven Central 下架(项目停维),
// ffmpeg_kit_flutter 6.0.3 的 Android 模块仍硬编码旧坐标,对所有项目(含
// pub cache 插件模块 :ffmpeg_kit_flutter)统一替换为社区重发布坐标
// ffmpegkit-maintained(6.0 LTS 线,FFmpeg n6.1.6,API 兼容)。
gradle.beforeProject {
    configurations.configureEach {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.arthenica:ffmpeg-kit-https"))
                .using(module("dev.ffmpegkit-maintained:ffmpeg-kit-min:6.0.3"))
        }
    }
}

include(":app")
