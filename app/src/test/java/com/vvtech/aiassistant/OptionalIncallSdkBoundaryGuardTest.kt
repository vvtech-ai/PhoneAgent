package com.vvtech.aiassistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OptionalIncallSdkBoundaryGuardTest {
    @Test
    fun publicBuildBundlesAuthorizedFirstPartyTrustedCallSdk() {
        val buildGradle = sourceFile("build.gradle").readText(Charsets.UTF_8)

        assertTrue(buildGradle.contains("fileTree(dir: \"private-libs\""))
        assertTrue(buildGradle.contains("libs/chaken-incall-1.5.aar"))
        assertTrue(buildGradle.contains("libs/chaken-incall-ui-1.5.aar"))
        assertTrue(sourceFile("libs/chaken-incall-1.5.aar").isFile)
        assertTrue(sourceFile("libs/chaken-incall-ui-1.5.aar").isFile)
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
        assertTrue(bridge.contains("Application::class.java"))
        assertTrue(bridge.contains("getMethod(\"init\", Application::class.java"))
        assertFalse(bridge.contains("getMethod(\"init\", Context::class.java"))
        assertTrue(bridge.contains("OPTIONAL_INCALL_SDK").not())
    }

    @Test
    fun appManifestPinsAppCompatThemeForAllVendorActivities() {
        val manifest = sourceFile("src/main/AndroidManifest.xml").readText(Charsets.UTF_8)
        val vendorActivities = listOf(
            "com.weway.chaken.incallsdk.MainActivity",
            "com.weway.chaken.incallsdk.AgreementActivity",
            "com.weway.chaken.incallsdk.NewSplashActivity",
            "com.weway.chaken.incallsdk.SettingActivity",
            "com.weway.chaken.incallsdk.AboutUsActivity",
            "com.weway.chaken.incallsdk.SettingFinishActivity",
            "com.weway.chaken.incallsdk.WebBrowserActivity",
            "com.weway.chaken.incallsdk.SelectSimLoginActivity",
            "com.weway.chaken.incallsdk.login.CountrySelectActivity",
            "com.weway.chaken.incallsdk.login.LoginActivity"
        )

        vendorActivities.forEach { activity ->
            assertTrue(manifest.contains("android:name=\"$activity\""))
        }
        val vendorThemeCount = Regex.fromLiteral(
            "android:theme=\"@style/Theme.ChakenIncall\""
        ).findAll(manifest).count()
        assertTrue(vendorThemeCount == vendorActivities.size)
    }

    private companion object {
        fun sourceFile(path: String): File = listOf(
            File(path),
            File("app/$path")
        ).first { it.exists() }
    }
}
