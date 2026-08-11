package com.vvtech.aiassistant.features.assistant_voice_clone

import java.util.Locale

internal object VoiceCloneUploadPolicy {
    fun isAcceptedProviderStatus(status: String?): Boolean = when (status?.uppercase(Locale.ROOT)) {
        "READY", "PROCESSING" -> true
        else -> false
    }

    fun isCompleted(status: String?): Boolean =
        status?.uppercase(Locale.ROOT) == "READY"

    fun toSubmissionState(status: String?): VoiceCloneSubmissionState =
        when (status?.uppercase(Locale.ROOT)) {
            "READY" -> VoiceCloneSubmissionState.READY
            "PROCESSING" -> VoiceCloneSubmissionState.PROCESSING
            "FAILED" -> VoiceCloneSubmissionState.FAILED
            else -> VoiceCloneSubmissionState.UNKNOWN
        }
}

internal enum class VoiceCloneSubmissionState {
    IDLE,
    SUBMITTING,
    PROCESSING,
    READY,
    FAILED,
    UNKNOWN
}
