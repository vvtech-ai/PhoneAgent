package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object ConversationStateReducer {

    fun prepareTextTurnSubmitting(
        state: Index9AssistantUiState,
        clearCallResult: Boolean,
        statusText: String
    ): Index9AssistantUiState {
        val baseState = if (clearCallResult) {
            AssistantUiStateReducer.clearCallResultUiForContinuation(state)
        } else {
            state
        }
        return baseState.copy(
            stage = AssistantStage.Clarifying,
            voiceManuallyPaused = false,
            processingTurn = true,
            error = null,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = statusText
        )
    }

    fun prepareVoiceSupplementSubmitting(
        state: Index9AssistantUiState,
        clearCallResult: Boolean,
        statusText: String
    ): Index9AssistantUiState {
        val baseState = if (clearCallResult) {
            AssistantUiStateReducer.clearCallResultUiForContinuation(state)
        } else {
            state
        }
        return baseState.copy(
            stage = AssistantStage.Clarifying,
            voiceConnecting = false,
            voiceActive = true,
            voiceManuallyPaused = false,
            voiceBackgroundPaused = false,
            listening = false,
            processingTurn = true,
            apiAsrListening = false,
            apiAsrPartialText = null,
            error = null,
            liveUserTranscript = null,
            liveAssistantTranscript = null,
            status = statusText
        )
    }
}
