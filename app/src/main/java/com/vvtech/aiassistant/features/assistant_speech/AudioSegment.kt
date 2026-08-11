package com.vvtech.aiassistant.features.assistant_speech

import com.vvtech.aiassistant.features.assistant.speech.TtsAudioFormat

internal data class AudioSegment(
    val id: Long,
    val bytes: ByteArray,
    val format: TtsAudioFormat,
    val enqueuedAtMs: Long
)
