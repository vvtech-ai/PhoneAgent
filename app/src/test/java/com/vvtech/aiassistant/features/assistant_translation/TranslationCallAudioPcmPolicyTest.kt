package com.vvtech.aiassistant.features.assistant_translation

import android.media.MediaRecorder
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranslationCallAudioPcmPolicyTest {
    @Test
    fun frameSizeUsesTwentyMsPcm16Frames() {
        assertEquals(640, TranslationCallAudioPcmPolicy.frameSizeBytes(16_000))
        assertEquals(320, TranslationCallAudioPcmPolicy.frameSizeBytes(8_000))
        assertEquals(1_920, TranslationCallAudioPcmPolicy.frameSizeBytes(48_000))
    }

    @Test
    fun normalizeKeepsSixteenKhzPayloadExact() {
        val buffer = byteArrayOf(1, 0, 2, 0, 3, 0)

        val normalized = TranslationCallAudioPcmPolicy.normalizeCaptureFrame(
            buffer = buffer,
            count = 4,
            sampleRate = TranslationCallAudioTargetSampleRate
        )

        assertArrayEquals(byteArrayOf(1, 0, 2, 0), normalized)
    }

    @Test
    fun normalizeDownSamplesFortyEightKhzFrameToSixteenKhz() {
        val input = ByteArray(TranslationCallAudioPcmPolicy.frameSizeBytes(48_000)) { index ->
            (index % 127).toByte()
        }

        val normalized = TranslationCallAudioPcmPolicy.normalizeCaptureFrame(
            buffer = input,
            count = input.size,
            sampleRate = 48_000
        )

        assertEquals(TranslationCallAudioPcmPolicy.frameSizeBytes(16_000), normalized.size)
        assertEquals(0, normalized.size % 2)
    }

    @Test
    fun captureConfigPolicyKeepsExistingFallbackOrderAndCursorAdvance() {
        val configs = TranslationCallAudioCaptureConfigPolicy.captureConfigs

        assertEquals(MediaRecorder.AudioSource.VOICE_COMMUNICATION, configs.first().source)
        assertEquals(16_000, configs.first().sampleRate)
        assertTrue(configs.any { it.source == MediaRecorder.AudioSource.MIC && it.sampleRate == 16_000 })

        val firstNext = TranslationCallAudioCaptureConfigPolicy.nextCursor(
            currentCursor = 0,
            source = configs.first().source,
            sampleRate = configs.first().sampleRate
        )
        assertEquals(1, firstNext)

        val unknownNext = TranslationCallAudioCaptureConfigPolicy.nextCursor(
            currentCursor = 3,
            source = -1,
            sampleRate = -1
        )
        assertEquals(4, unknownNext)
    }

    @Test
    fun socketClientDelegatesPcmAndCapturePolicy() {
        val clientFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant/TranslationCallAudioSocketClient.kt"
        )
        val policyFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_translation/TranslationCallAudioPcmPolicy.kt"
        )
        val client = clientFile.readText(Charsets.UTF_8)
        val policy = policyFile.readText(Charsets.UTF_8)

        assertTrue(clientFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue(policyFile.readLines(Charsets.UTF_8).size <= 300)
        assertTrue(client.contains("TranslationCallAudioPcmPolicy.frameSizeBytes("))
        assertTrue(client.contains("TranslationCallAudioPcmPolicy.normalizeCaptureFrame("))
        assertTrue(client.contains("TranslationCallAudioCaptureConfigPolicy.captureConfigs"))
        assertTrue(client.contains("TranslationCallAudioCaptureConfigPolicy.nextCursor("))

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
            "data class TranslationCallAudioCaptureConfig",
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
