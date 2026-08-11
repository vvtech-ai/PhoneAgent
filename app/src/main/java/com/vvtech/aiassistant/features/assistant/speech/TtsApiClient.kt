package com.vvtech.aiassistant.features.assistant.speech

interface TtsApiClient {
    val audioFormat: TtsAudioFormat
        get() = TtsAudioFormat.Mp3

    suspend fun synthesize(
        text: String,
        speaker: String = DEFAULT_TTS_SPEAKER,
        onAudioChunk: (ByteArray) -> Unit,
        onComplete: () -> Unit,
        onError: (Throwable) -> Unit
    )

    fun cancel()

    fun close(reason: String) {
        cancel()
    }

    fun close() {
        close("close")
    }
}

enum class TtsAudioFormat {
    Mp3,
    Pcm16k16BitMono,
    Pcm24k16BitMono
}

const val DEFAULT_TTS_SPEAKER = "zh_male_taocheng_uranus_bigtts"
