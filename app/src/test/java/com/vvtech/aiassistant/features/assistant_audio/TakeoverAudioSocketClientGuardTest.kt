package com.vvtech.aiassistant.features.assistant_audio

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TakeoverAudioSocketClientGuardTest {
    @Test
    fun socketClientDelegatesPcmAndCapturePolicy() {
        val clientFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/TakeoverAudioSocketClient.kt"
        )
        val policyFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_audio/TakeoverAudioPcmPolicy.kt"
        )
        val client = clientFile.readText(Charsets.UTF_8)
        val policy = policyFile.readText(Charsets.UTF_8)

        assertTrue(clientFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(policyFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(client.contains("TakeoverAudioPcmPolicy.frameSizeBytes("))
        assertTrue(client.contains("TakeoverAudioPcmPolicy.normalizeCaptureFrame("))
        assertTrue(client.contains("TakeoverAudioCaptureConfigPolicy.captureConfigs"))
        assertTrue(client.contains("TakeoverAudioCaptureConfigPolicy.nextCursor("))

        listOf(
            "private fun normalizeCaptureFrame(",
            "private fun bytesToShorts(",
            "private fun shortsToBytes(",
            "private fun resampleLinear(",
            "private data class CaptureConfig",
            "MediaRecorder.AudioSource"
        ).forEach { token ->
            assertFalse("socket client should not own PCM/capture policy token: $token", client.contains(token))
        }

        listOf(
            "fun normalizeCaptureFrame(",
            "private fun bytesToShorts(",
            "private fun shortsToBytes(",
            "private fun resampleLinear(",
            "data class TakeoverAudioCaptureConfig",
            "MediaRecorder.AudioSource"
        ).forEach { token ->
            assertTrue("policy should own PCM/capture policy token: $token", policy.contains(token))
        }
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
