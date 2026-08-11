package com.vvtech.aiassistant.voice

data class VoiceRuntimeConfig(
    val appId: String,
    val roomId: String,
    val userId: String,
    val token: String
)

enum class VoiceTranscriptSpeaker {
    LocalUser,
    RemoteAssistant,
    Unknown
}

sealed interface VoiceRuntimeEvent {
    data class Connecting(val message: String) : VoiceRuntimeEvent
    data class Status(val message: String) : VoiceRuntimeEvent
    data class Connected(val message: String) : VoiceRuntimeEvent
    data class Transcript(
        val speaker: VoiceTranscriptSpeaker,
        val text: String,
        val definite: Boolean
    ) : VoiceRuntimeEvent
    data class Error(val message: String) : VoiceRuntimeEvent
    object Stopped : VoiceRuntimeEvent
}
