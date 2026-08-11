package com.vvtech.aiassistant.callengine

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.round

internal object AssistantPcmResampler {
    fun resample(input: ShortArray?, sourceRate: Int, targetRate: Int): ShortArray {
        if (input == null || input.isEmpty() || sourceRate <= 0 || targetRate <= 0) {
            return ShortArray(0)
        }
        if (sourceRate == targetRate) return input.copyOf()
        if (sourceRate == targetRate * 2) return downsampleBy2(input)
        val outputLength = max(1, round(input.size.toDouble() * targetRate / sourceRate).toInt())
        val output = ShortArray(outputLength)
        val step = sourceRate.toDouble() / targetRate
        for (index in output.indices) {
            val position = index * step
            val left = floor(position).toInt().coerceIn(0, input.lastIndex)
            val right = min(left + 1, input.lastIndex)
            val fraction = position - left
            output[index] = clamp(round(input[left] * (1 - fraction) + input[right] * fraction).toLong())
        }
        return output
    }

    fun toLittleEndian(pcm: ShortArray): ByteArray {
        val output = ByteArray(pcm.size * 2)
        pcm.indices.forEach { index ->
            output[index * 2] = (pcm[index].toInt() and 0xFF).toByte()
            output[index * 2 + 1] = ((pcm[index].toInt() ushr 8) and 0xFF).toByte()
        }
        return output
    }

    fun fromLittleEndian(payload: ByteArray?): ShortArray {
        if (payload == null || payload.isEmpty()) return ShortArray(0)
        return ShortArray(payload.size / 2) { index ->
            val low = payload[index * 2].toInt() and 0xFF
            val high = payload[index * 2 + 1].toInt() shl 8
            (high or low).toShort()
        }
    }

    private fun downsampleBy2(input: ShortArray): ShortArray {
        val output = ShortArray(max(1, input.size / 2))
        output.indices.forEach { index ->
            val center = index * 2
            val sample = sample(input, center - 2) +
                (sample(input, center - 1) shl 2) +
                sample(input, center) * 6 +
                (sample(input, center + 1) shl 2) +
                sample(input, center + 2)
            output[index] = clamp(round(sample / 16.0).toLong())
        }
        return output
    }

    private fun sample(input: ShortArray, index: Int): Int =
        input[index.coerceIn(0, input.lastIndex)].toInt()

    private fun clamp(value: Long): Short =
        value.coerceIn(Short.MIN_VALUE.toLong(), Short.MAX_VALUE.toLong()).toShort()
}
