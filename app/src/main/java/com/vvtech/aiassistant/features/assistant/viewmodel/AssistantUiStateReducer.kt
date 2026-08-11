package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.CallUiMode
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object AssistantUiStateReducer {

    fun setIdentityInitOverlayVisible(
        state: Index9AssistantUiState,
        visible: Boolean
    ): Index9AssistantUiState {
        return if (state.identityInitOverlayVisible == visible) {
            state
        } else {
            state.copy(identityInitOverlayVisible = visible)
        }
    }

    fun updateLocationAvailability(
        state: Index9AssistantUiState,
        available: Boolean,
        displayText: String
    ): Index9AssistantUiState {
        return state.copy(
            locationAvailable = available,
            locationDisplayText = displayText
        )
    }

    fun updateLocationDisplayText(
        state: Index9AssistantUiState,
        displayText: String
    ): Index9AssistantUiState {
        return state.copy(locationDisplayText = displayText)
    }

    fun clearCallResultUiForContinuation(
        state: Index9AssistantUiState
    ): Index9AssistantUiState {
        return state.copy(
            callUiMode = CallUiMode.Ai,
            currentCallId = null,
            handoffInFlight = false,
            showAiCallPage = false,
            agentCallSpec = null,
            agentCallResult = null
        )
    }

    fun applyEmptyRecognizedTurn(
        state: Index9AssistantUiState,
        status: String
    ): Index9AssistantUiState {
        return state.copy(
            listening = false,
            processingTurn = false,
            liveUserTranscript = null,
            status = status
        )
    }

    fun clearLocalAssistantSpeaking(
        state: Index9AssistantUiState
    ): Index9AssistantUiState {
        return state.copy(
            localTtsSpeaking = false,
            liveAssistantTranscript = null
        )
    }
}
