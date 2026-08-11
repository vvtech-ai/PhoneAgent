package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal interface VoiceAsrWatchdogCallbacks {
    fun onAsrReady(source: String)
    fun onAsrPartial(text: String, source: String)
    fun onProviderError(source: String)
    fun onProviderClosed(source: String)
    fun onManualAsrTimeout(source: String)
    fun startBackendSpeechFallback()
}

internal const val ASR_NO_EVENT_TIMEOUT_MS = 8_000L
internal const val ASR_PARTIAL_COMMIT_TIMEOUT_MS = 3_200L
internal const val ASR_IDLE_TIMEOUT_MS = 60_000L

private val VOICE_ASR_METADATA_PATTERN = Regex(
    """[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*v?\d+\.\d+""",
    RegexOption.IGNORE_CASE
)

internal fun looksLikeAsrMetadata(text: String): Boolean {
    val trimmed = text.trim()
    if (trimmed.isBlank()) return false
    return VOICE_ASR_METADATA_PATTERN.containsMatchIn(trimmed)
}

internal fun Index9AssistantUiState.pausedAfterAsrWatchdog(statusText: String): Index9AssistantUiState =
    copy(
        voiceManuallyPaused = true,
        voiceBackgroundPaused = false,
        voiceActive = true,
        voiceConnecting = false,
        listening = false,
        processingTurn = false,
        apiAsrListening = false,
        apiAsrPartialText = null,
        liveUserTranscript = null,
        status = statusText
    )
