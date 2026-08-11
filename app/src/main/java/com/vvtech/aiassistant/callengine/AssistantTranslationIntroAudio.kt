package com.vvtech.aiassistant.callengine

import android.content.Context
import com.vvtech.aiassistant.R
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale

internal object AssistantTranslationConnectPromptPolicy {
    fun isEnabled(mode: AssistantCallMode): Boolean = mode == AssistantCallMode.TRANSLATION
}

internal object AssistantTranslationIntroAudio {
    const val TailSilenceFrames = 30
    private const val ProviderFrameSamples = 320
    private const val ProviderSampleRate = 16_000

    fun languageCode(language: String): String {
        val normalized = language.trim().lowercase(Locale.US).replace('_', '-')
        return when (normalized.substringBefore('-')) {
            "zh", "cn", "chinese" -> "zh"
            "ja", "jp", "japanese" -> "ja"
            "en", "english" -> "en"
            else -> DefaultIntroLanguageCode
        }
    }

    fun loadFrames(context: Context, language: String): List<ShortArray> {
        val languageCode = languageCode(language)
        val resourceId = when (languageCode) {
            "zh" -> R.raw.translation_intro_zh
            "ja" -> R.raw.translation_intro_ja
            "en" -> R.raw.translation_intro_en
            else -> error("unsupported_language")
        }
        val wav = context.resources.openRawResource(resourceId).use { it.readBytes() }
        return suppressLongQuietIntervals(frames(wav))
    }

    fun loadTriggerFrames(context: Context): List<ShortArray> {
        val wav = context.resources.openRawResource(R.raw.translation_intro_trigger_zh)
            .use { it.readBytes() }
        return frames(wav)
    }

    fun frames(wav: ByteArray): List<ShortArray> {
        val pcm = decodePcm16MonoWav(wav)
        return framesFromPcm16(pcm.samples, pcm.sampleRate)
    }

    fun framesFromPcm16(pcm16: ShortArray, sampleRate: Int): List<ShortArray> {
        require(pcm16.isNotEmpty()) { "translation intro audio is empty" }
        val pcm16k = AssistantPcmResampler.resample(pcm16, sampleRate, ProviderSampleRate)
        require(pcm16k.isNotEmpty()) { "translation intro audio is empty" }
        return pcm16k.indices
            .step(ProviderFrameSamples)
            .map { offset ->
                ShortArray(ProviderFrameSamples).also { frame ->
                    val copyLength = minOf(ProviderFrameSamples, pcm16k.size - offset)
                    System.arraycopy(pcm16k, offset, frame, 0, copyLength)
                }
            }
    }

    fun silenceFrame(): ShortArray = ShortArray(ProviderFrameSamples)

    fun suppressLongQuietIntervals(frames: List<ShortArray>): List<ShortArray> {
        if (frames.isEmpty()) return frames
        val result = frames.toMutableList()
        var quietStart = -1
        for (index in 0..frames.size) {
            val quiet = index < frames.size && rms(frames[index]) <= QuietRmsThreshold
            if (quiet && quietStart < 0) {
                quietStart = index
            } else if (!quiet && quietStart >= 0) {
                if (index - quietStart >= MinQuietIntervalFrames) {
                    for (quietIndex in quietStart until index) {
                        result[quietIndex] = silenceFrame()
                    }
                }
                quietStart = -1
            }
        }
        return result
    }

    private fun rms(frame: ShortArray): Double {
        if (frame.isEmpty()) return 0.0
        return kotlin.math.sqrt(
            frame.sumOf { sample -> sample.toDouble() * sample.toDouble() } / frame.size
        )
    }

    private fun decodePcm16MonoWav(wav: ByteArray): PcmData {
        require(wav.size >= 44) { "wav_header_too_short" }
        require(wav.ascii(0, 4) == "RIFF" && wav.ascii(8, 4) == "WAVE") {
            "invalid_wav_header"
        }
        var offset = 12
        var format: WavFormat? = null
        var dataOffset = -1
        var dataSize = 0
        while (offset + 8 <= wav.size) {
            val chunkId = wav.ascii(offset, 4)
            val chunkSize = wav.intLe(offset + 4)
            val payloadOffset = offset + 8
            require(chunkSize >= 0 && payloadOffset + chunkSize <= wav.size) {
                "invalid_wav_chunk"
            }
            when (chunkId) {
                "fmt " -> format = parseFormat(wav, payloadOffset, chunkSize)
                "data" -> {
                    dataOffset = payloadOffset
                    dataSize = chunkSize
                }
            }
            offset = payloadOffset + chunkSize + (chunkSize and 1)
        }
        val resolvedFormat = format ?: error("missing_wav_format")
        require(dataOffset >= 0 && dataSize > 0) { "missing_wav_data" }
        require(resolvedFormat.audioFormat == 1) { "unsupported_wav_format" }
        require(resolvedFormat.channels == 1) { "unsupported_wav_channels" }
        require(resolvedFormat.bitsPerSample == 16) { "unsupported_wav_bits" }
        val sampleCount = dataSize / 2
        val data = wav.copyOfRange(dataOffset, dataOffset + sampleCount * 2)
        return PcmData(
            samples = AssistantPcmResampler.fromLittleEndian(data),
            sampleRate = resolvedFormat.sampleRate
        )
    }

    private fun parseFormat(wav: ByteArray, offset: Int, size: Int): WavFormat {
        require(size >= 16) { "invalid_wav_format" }
        return WavFormat(
            audioFormat = wav.shortLe(offset).toInt(),
            channels = wav.shortLe(offset + 2).toInt(),
            sampleRate = wav.intLe(offset + 4),
            bitsPerSample = wav.shortLe(offset + 14).toInt()
        )
    }

    private fun ByteArray.ascii(offset: Int, length: Int): String =
        copyOfRange(offset, offset + length).toString(Charsets.US_ASCII)

    private fun ByteArray.shortLe(offset: Int): Short =
        ByteBuffer.wrap(this, offset, 2).order(ByteOrder.LITTLE_ENDIAN).short

    private fun ByteArray.intLe(offset: Int): Int =
        ByteBuffer.wrap(this, offset, 4).order(ByteOrder.LITTLE_ENDIAN).int

    private data class WavFormat(
        val audioFormat: Int,
        val channels: Int,
        val sampleRate: Int,
        val bitsPerSample: Int
    )

    private data class PcmData(
        val samples: ShortArray,
        val sampleRate: Int
    )

    private const val QuietRmsThreshold = 64.0
    private const val MinQuietIntervalFrames = 10
    private const val DefaultIntroLanguageCode = "en"
}
