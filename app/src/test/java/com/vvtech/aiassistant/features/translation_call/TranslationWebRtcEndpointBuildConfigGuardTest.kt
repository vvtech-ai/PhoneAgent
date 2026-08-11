package com.vvtech.aiassistant.features.translation_call

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationWebRtcEndpointBuildConfigGuardTest {
    @Test
    fun `gradle defaults use production route and keep regional overrides configurable`() {
        val buildGradle = locateAppBuildGradle().readText()

        assertTrue(buildGradle.contains("https://translate-us-webrtc.vvtech.tech"))
        assertTrue(buildGradle.contains("assistantTranslationWebRtcUsUrl"))
        assertTrue(buildGradle.contains("assistantTranslationWebRtcJpUrl"))
        assertFalse(buildGradle.contains("translate-test-"))
        assertTrue(buildGradle.contains("versionCode 30"))
        assertTrue(buildGradle.contains("versionName \"1.0.36\""))
    }

    private fun locateAppBuildGradle(): File {
        val candidates = listOf(
            File("build.gradle"),
            File("app/build.gradle"),
            File("android/app/build.gradle"),
        )
        return candidates.firstOrNull(File::isFile)
            ?: error("Unable to locate android/app/build.gradle")
    }
}
