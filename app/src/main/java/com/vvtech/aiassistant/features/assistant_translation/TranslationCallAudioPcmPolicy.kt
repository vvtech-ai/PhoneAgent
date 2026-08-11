package com.vvtech.aiassistant.features.assistant_translation

import android.media.MediaRecorder
import kotlin.math.floor

internal const val TranslationCallAudioTargetSampleRate = 16_000

internal data class TranslationCallAudioCaptureConfig(
    val source: Int,
    val sampleRate: Int
)

internal object TranslationCallAudioCaptureConfigPolicy {
    val captureConfigs: List<TranslationCallAudioCaptureConfig> = listOf(
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.VOICE_COMMUNICATION, 16_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.MIC, 16_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.VOICE_RECOGNITION, 16_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.DEFAULT, 16_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.CAMCORDER, 16_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.VOICE_COMMUNICATION, 48_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.MIC, 48_000),
        TranslationCallAudioCaptureConfig(MediaRecorder.AudioSource.DEFAULT, 48_000)
    )

    fun nextCursor(currentCursor: Int, source: Int, sampleRate: Int): Int {
        val currentIndex = captureConfigs.indexOfFirst {
            it.source == source && it.sampleRate == sampleRate
        }
        return if (currentIndex >= 0) {
            (currentIndex + 1) % captureConfigs.size
        } else {
            (currentCursor + 1) % captureConfigs.size
        }
    }
}

internal object TranslationCallAudioPcmPolicy {
    fun frameSizeBytes(sampleRate: Int): Int {
        val samplesPer20ms = maxOf(1, sampleRate / 50)
        return samplesPer20ms * 2
    }

    fun normalizeCaptureFrame(buffer: ByteArray, count: Int, sampleRate: Int): ByteArray {
        val exact = buffer.copyOf(count)
        if (sampleRate == TranslationCallAudioTargetSampleRate) {
            return exact
        }
        val sourceShorts = bytesToShorts(exact)
        if (sourceShorts.isEmpty()) return ByteArray(0)
        val resampled = resampleLinear(sourceShorts, sampleRate, TranslationCallAudioTargetSampleRate)
        return shortsToBytes(resampled)
    }

    private fun bytesToShorts(payload: ByteArray): ShortArray {
        val size = payload.size / 2
        val out = ShortArray(size)
        for (i in 0 until size) {
            val low = payload[i * 2].toInt() and 0xFF
            val high = payload[i * 2 + 1].toInt() shl 8
            out[i] = (high or low).toShort()
        }
        return out
    }

    private fun shortsToBytes(pcm: ShortArray): ByteArray {
        val out = ByteArray(pcm.size * 2)
        for (i in pcm.indices) {
            out[i * 2] = (pcm[i].toInt() and 0xFF).toByte()
            out[i * 2 + 1] = ((pcm[i].toInt() shr 8) and 0xFF).toByte()
        }
        return out
    }

    private fun resampleLinear(input: ShortArray, sourceRate: Int, targetRate: Int): ShortArray {
        if (input.isEmpty()) return ShortArray(0)
        if (sourceRate == targetRate) return input
        val outputLength = maxOf(1, ((input.size.toDouble() * targetRate) / sourceRate).toInt())
        val output = ShortArray(outputLength)
        val step = sourceRate.toDouble() / targetRate.toDouble()
        for (i in 0 until outputLength) {
            val position = i * step
            val leftIndex = floor(position).toInt().coerceIn(0, input.lastIndex)
            val rightIndex = (leftIndex + 1).coerceAtMost(input.lastIndex)
            val fraction = position - leftIndex
            val sample = input[leftIndex] * (1.0 - fraction) + input[rightIndex] * fraction
            output[i] = sample.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return output
    }
}
