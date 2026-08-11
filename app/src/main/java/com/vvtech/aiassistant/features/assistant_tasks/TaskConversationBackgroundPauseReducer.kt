package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoicePauseSource
import com.vvtech.aiassistant.features.assistant.voicePauseFlagsFor

internal object TaskConversationBackgroundPauseReducer {
    private const val BackgroundPauseStatus = "已暂停，返回后可继续"

    fun apply(state: Index9AssistantUiState): Index9AssistantUiState {
        val pauseFlags = voicePauseFlagsFor(VoicePauseSource.Background)
        return state.copy(
            listening = false,
            voiceConnecting = false,
            voiceActive = false,
            voiceManuallyPaused = pauseFlags.manuallyPaused,
            voiceBackgroundPaused = pauseFlags.backgroundPaused,
            processingTurn = false,
            loading = false,
            apiAsrListening = false,
            apiAsrPartialText = null,
            apiTtsPlaying = false,
            localTtsSpeaking = false,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = if (state.clarificationSteps.isNotEmpty()) {
                BackgroundPauseStatus
            } else {
                state.status
            }
        )
    }
}
