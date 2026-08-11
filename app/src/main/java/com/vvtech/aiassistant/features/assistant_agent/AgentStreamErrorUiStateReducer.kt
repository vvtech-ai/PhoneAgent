package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object AgentStreamErrorUiStateReducer {

    fun applyStreamError(
        state: Index9AssistantUiState,
        message: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = false,
            loading = false,
            error = message,
            status = message
        )
    }

    fun applyExecutionError(
        state: Index9AssistantUiState,
        errorText: String,
        statusText: String = errorText,
        clearDocumentImporting: Boolean = false
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = false,
            loading = false,
            taskStatus = EXECUTION_ERROR,
            unresolvedTaskErrorStatus = EXECUTION_ERROR,
            taskErrorRecoveryInProgress = false,
            error = errorText,
            status = statusText,
            agentDocumentImporting = if (clearDocumentImporting) false else state.agentDocumentImporting
        )
    }

    fun applyVoiceRecovery(
        state: Index9AssistantUiState,
        statusText: String,
        resetManualPause: Boolean = false,
        clearDocumentImporting: Boolean = false
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = false,
            loading = false,
            error = null,
            status = statusText,
            voiceManuallyPaused = if (resetManualPause) false else state.voiceManuallyPaused,
            agentDocumentImporting = if (clearDocumentImporting) false else state.agentDocumentImporting
        )
    }

    fun applyBatchSyncPending(
        state: Index9AssistantUiState,
        statusText: String,
        clearError: Boolean
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = false,
            loading = false,
            listening = false,
            voiceConnecting = false,
            apiAsrListening = false,
            apiAsrPartialText = null,
            error = if (clearError) null else state.error,
            status = statusText
        )
    }

    private const val EXECUTION_ERROR = "EXECUTION_ERROR"
}
