package com.vvtech.aiassistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OptionalIncallSdkBoundaryGuardTest {
    @Test
    fun publicBuildDoesNotRequireBundledProprietarySdk() {
        val buildGradle = sourceFile("build.gradle").readText(Charsets.UTF_8)

        assertTrue(buildGradle.contains("fileTree(dir: \"private-libs\""))
        assertFalse(buildGradle.contains("fileTree(dir: \"libs\""))
        assertFalse(buildGradle.contains("fileTree(dir: \"runtime\""))
    }

    @Test
    fun applicationUsesReflectionBoundary() {
        val application = sourceFile(
            "src/main/java/com/vvtech/aiassistant/AIAssistantApplication.kt"
        ).readText(Charsets.UTF_8)
        val bridge = sourceFile(
            "src/main/java/com/vvtech/aiassistant/integration/incall/OptionalIncallSdkBridge.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(application.contains("OptionalIncallSdkBridge.installProtection(this)"))
        assertTrue(application.contains("initializeOptionalIncallSdk()"))
        assertTrue(application.contains("OptionalIncallSdkBridge.initialize("))
        assertFalse(application.contains("import com.weway.chaken"))
        assertFalse(application.contains("com.secneo.weway.Helper.install"))
        assertTrue(bridge.contains("Class.forName(SdkClass)"))
        assertTrue(bridge.contains("OPTIONAL_INCALL_SDK").not())
    }

    @Test
    fun publicManifestDoesNotDeclareVendorActivities() {
        val manifest = sourceFile("src/main/AndroidManifest.xml").readText(Charsets.UTF_8)

        assertFalse(manifest.contains("com.weway.chaken.incallsdk"))
        assertFalse(manifest.contains("Theme.ChakenIncall"))
    }

    private companion object {
        fun sourceFile(path: String): File = listOf(
            File(path),
            File("app/$path")
        ).first { it.exists() }
    }
}
