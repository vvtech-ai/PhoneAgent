package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

internal object VoiceCloneAudioQualityAnalyzer {

    private const val WavHeaderBytes = 44
    private const val MaxClippedRatio = 0.01
    private const val MinRmsRatio = 0.015
    private const val MaxSilenceRatio = 0.70
    private const val SilenceAbsThreshold = 240
    private const val NoiseZeroCrossingRatio = 0.20

    data class QualityReport(
        val warnings: List<String>,
        val blockedReason: String?
    ) {
        val blocked: Boolean
            get() = !blockedReason.isNullOrBlank()
    }

    fun analyze(file: File, minDurationSeconds: Int, targetDurationSeconds: Int): QualityReport {
        if (!file.exists() || file.length() <= WavHeaderBytes) {
            return QualityReport(emptyList(), "录音文件为空，请重新录制。")
        }
        return runCatching {
            RandomAccessFile(file, "r").use { raf ->
                val header = ByteArray(WavHeaderBytes)
                raf.readFully(header)
                val sampleRate = littleEndianInt(header, 24)
                val bitsPerSample = littleEndianShort(header, 34)
                if (bitsPerSample != 16) {
                    return QualityReport(emptyList(), "当前仅支持 PCM16 WAV 录音，请重新录制。")
                }
                val audioBytes = ByteArray((raf.length() - WavHeaderBytes).toInt())
                raf.readFully(audioBytes)
                val samples = ShortArray(audioBytes.size / 2)
                var cursor = 0
                while (cursor < samples.size) {
                    val lo = audioBytes[cursor * 2].toInt() and 0xFF
                    val hi = audioBytes[cursor * 2 + 1].toInt()
                    samples[cursor] = ((hi shl 8) or lo).toShort()
                    cursor++
                }
                inspectSamples(samples, sampleRate, minDurationSeconds, targetDurationSeconds)
            }
        }.getOrElse { throwable ->
            QualityReport(emptyList(), throwable.message ?: currentAppText(
                "录音分析失败，请重新录制。",
                "Recording analysis failed. Please record again."
            ))
        }
    }

    private fun inspectSamples(
        samples: ShortArray,
        sampleRate: Int,
        minDurationSeconds: Int,
        targetDurationSeconds: Int
    ): QualityReport {
        if (samples.isEmpty() || sampleRate <= 0) {
            return QualityReport(emptyList(), "录音内容为空，请重新录制。")
        }
        val durationSeconds = samples.size.toDouble() / sampleRate.toDouble()
        if (durationSeconds < minDurationSeconds.toDouble()) {
            return QualityReport(emptyList(), "录音时长过短，请至少录满 $minDurationSeconds 秒。")
        }

        var clipped = 0
        var silent = 0
        var zeroCrossings = 0
        var squareSum = 0.0
        for (index in samples.indices) {
            val current = samples[index].toInt()
            val amplitude = abs(current)
            squareSum += amplitude.toDouble() * amplitude.toDouble()
            if (amplitude >= 32760) clipped++
            if (amplitude <= SilenceAbsThreshold) silent++
            if (index > 0) {
                val previous = samples[index - 1].toInt()
                if ((current > 0 && previous < 0) || (current < 0 && previous > 0)) {
                    zeroCrossings++
                }
            }
        }

        val rms = sqrt(squareSum / samples.size) / 32768.0
        val clippedRatio = clipped / samples.size.toDouble()
        val silenceRatio = silent / samples.size.toDouble()
        val zeroCrossingRatio = zeroCrossings / max(1.0, samples.size.toDouble())

        if (rms < MinRmsRatio) {
            return QualityReport(emptyList(), "音量偏低，请靠近麦克风并在安静环境重新录制。")
        }
        if (clippedRatio > MaxClippedRatio) {
            return QualityReport(emptyList(), "录音有明显爆音，请降低说话音量后重录。")
        }
        if (silenceRatio > MaxSilenceRatio) {
            return QualityReport(emptyList(), "静音占比过高，请完整读完脚本后重新录制。")
        }

        val warnings = buildList {
            if (durationSeconds < targetDurationSeconds.toDouble()) {
                add("建议把本段控制在 ${targetDurationSeconds} 秒左右，当前约 ${durationSeconds.roundToInt()} 秒。")
            }
            if (zeroCrossingRatio > NoiseZeroCrossingRatio && rms < 0.05) {
                add("环境噪声有点明显，建议换更安静的位置再录一次。")
            }
            if (rms > 0.22) {
                add("音量略大，保持自然说话会更稳定。")
            }
            if (sampleRate < 24_000) {
                add("当前录音采样率低于 24kHz，建议检查设备录音链路。")
            }
        }
        return QualityReport(warnings, null)
    }

    private fun littleEndianInt(buffer: ByteArray, offset: Int): Int {
        return (buffer[offset].toInt() and 0xFF) or
            ((buffer[offset + 1].toInt() and 0xFF) shl 8) or
            ((buffer[offset + 2].toInt() and 0xFF) shl 16) or
            ((buffer[offset + 3].toInt() and 0xFF) shl 24)
    }

    private fun littleEndianShort(buffer: ByteArray, offset: Int): Int {
        return (buffer[offset].toInt() and 0xFF) or
            ((buffer[offset + 1].toInt() and 0xFF) shl 8)
    }
}
