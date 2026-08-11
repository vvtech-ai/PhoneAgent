package com.vvtech.aiassistant

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HostedBackendBuildConfigGuardTest {
    @Test
    fun prodAndDevDefaultToOpenSourceHostedBackend() {
        val buildGradle = listOf(
            File("build.gradle"),
            File("app/build.gradle")
        ).first { it.isFile }.readText(Charsets.UTF_8)

        assertTrue(
            buildGradle.contains("https://chaken-ai.vvtech.tech/aiassistant-api/")
        )
        assertFalse(
            buildGradle.contains("https://chaken.ai/aiassistant-api/")
        )
    }
}
