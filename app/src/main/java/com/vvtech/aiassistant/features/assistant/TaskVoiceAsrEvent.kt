package com.vvtech.aiassistant.features.assistant

internal sealed class TaskVoiceAsrEvent {
    object Connecting : TaskVoiceAsrEvent()
    object Ready : TaskVoiceAsrEvent()
    data class Closed(
        val reason: String = TaskVoiceCloseReason.ProviderClosed.logKey
    ) : TaskVoiceAsrEvent()
    data class Status(val message: String) : TaskVoiceAsrEvent()
    data class PartialTranscript(
        val text: String,
        val turnId: String? = null
    ) : TaskVoiceAsrEvent()
    data class FinalTranscript(
        val text: String,
        val turnId: String? = null
    ) : TaskVoiceAsrEvent()
    data class Error(val message: String) : TaskVoiceAsrEvent()
}
