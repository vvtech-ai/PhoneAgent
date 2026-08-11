package com.vvtech.aiassistant.features.assistant

internal enum class VoicePauseSource {
    User,
    Background
}

internal data class VoicePauseFlags(
    val manuallyPaused: Boolean,
    val backgroundPaused: Boolean
)

internal fun voicePauseFlagsFor(source: VoicePauseSource): VoicePauseFlags =
    when (source) {
        VoicePauseSource.User -> VoicePauseFlags(manuallyPaused = true, backgroundPaused = false)
        VoicePauseSource.Background -> VoicePauseFlags(manuallyPaused = false, backgroundPaused = true)
    }

internal fun shouldHoldVoiceAfterPromptPlayback(
    manuallyPaused: Boolean,
    backgroundPaused: Boolean
): Boolean = manuallyPaused || backgroundPaused
