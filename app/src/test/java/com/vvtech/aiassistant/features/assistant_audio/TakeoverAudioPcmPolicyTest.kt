package com.vvtech.aiassistant.features.assistant_audio

import android.media.MediaRecorder
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TakeoverAudioPcmPolicyTest {
    @Test
    fun frameSizeUsesTwentyMsPcm16Frames() {
        assertEquals(640, TakeoverAudioPcmPolicy.frameSizeBytes(16_000))
        assertEquals(320, TakeoverAudioPcmPolicy.frameSizeBytes(8_000))
        assertEquals(1_920, TakeoverAudioPcmPolicy.frameSizeBytes(48_000))
    }

    @Test
    fun normalizeKeepsSixteenKhzPayloadExact() {
        val buffer = byteArrayOf(1, 0, 2, 0, 3, 0)

        val normalized = TakeoverAudioPcmPolicy.normalizeCaptureFrame(
            buffer = buffer,
            count = 4,
            sampleRate = TakeoverAudioTargetSampleRate
        )

        assertArrayEquals(byteArrayOf(1, 0, 2, 0), normalized)
    }

    @Test
    fun normalizeDownSamplesFortyEightKhzFrameToSixteenKhz() {
        val input = ByteArray(TakeoverAudioPcmPolicy.frameSizeBytes(48_000)) { index ->
            (index % 127).toByte()
        }

        val normalized = TakeoverAudioPcmPolicy.normalizeCaptureFrame(
            buffer = input,
            count = input.size,
            sampleRate = 48_000
        )

        assertEquals(TakeoverAudioTargetFrameSizeBytes, normalized.size)
        assertEquals(0, normalized.size % 2)
    }

    @Test
    fun captureConfigPolicyKeepsExistingFallbackOrderAndCursorAdvance() {
        val configs = TakeoverAudioCaptureConfigPolicy.captureConfigs

        assertEquals(MediaRecorder.AudioSource.VOICE_COMMUNICATION, configs.first().source)
        assertEquals(16_000, configs.first().sampleRate)
        assertTrue(configs.any { it.source == MediaRecorder.AudioSource.MIC && it.sampleRate == 16_000 })

        val firstNext = TakeoverAudioCaptureConfigPolicy.nextCursor(
            currentCursor = 0,
            source = configs.first().source,
            sampleRate = configs.first().sampleRate
        )
        assertEquals(1, firstNext)

        val unknownNext = TakeoverAudioCaptureConfigPolicy.nextCursor(
            currentCursor = 3,
            source = -1,
            sampleRate = -1
        )
        assertEquals(4, unknownNext)
    }
}
