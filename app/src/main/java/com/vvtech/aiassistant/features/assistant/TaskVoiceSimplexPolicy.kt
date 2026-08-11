package com.vvtech.aiassistant.features.assistant

internal fun shouldArmTaskAsrDuringSimplexPlayback(): Boolean = false

internal fun shouldIgnoreTaskAsrEventDuringSimplexPlayback(
    apiTtsPlaying: Boolean,
    localTtsSpeaking: Boolean,
    localTtsPlaying: Boolean
): Boolean = apiTtsPlaying || localTtsSpeaking || localTtsPlaying

internal fun shouldResumeTaskAsrAfterSimplexPlayback(
    isVoiceChannel: Boolean,
    asrListening: Boolean,
    recording: Boolean,
    manuallyPaused: Boolean,
    backgroundPaused: Boolean,
    terminalCallResult: Boolean
): Boolean = false
