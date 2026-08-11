package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal object AgentStreamActionSubmitStatePolicy {
    fun optionSelected(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = true,
            error = null,
            agentOptions = null,
            status = statusText
        )
    }

    fun answersSubmitted(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = true,
            error = null,
            agentQuestions = null,
            agentPendingToolCallId = null,
            status = statusText
        )
    }

    fun permissionResultSubmitted(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = true,
            error = null,
            agentPermissionRequest = null,
            agentPendingToolCallId = null,
            status = statusText
        )
    }

    fun documentSubmitted(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            processingTurn = true,
            error = null,
            agentDocumentRequest = null,
            agentDocumentImporting = false,
            agentPendingToolCallId = null,
            status = statusText
        )
    }
}
