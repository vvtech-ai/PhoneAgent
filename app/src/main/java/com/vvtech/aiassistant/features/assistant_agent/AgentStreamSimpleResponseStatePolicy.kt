package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState

internal enum class AgentStreamRecoveryConfirmation {
    None,
    PromoteRunning,
    TerminalNoPromote
}

internal object AgentStreamSimpleResponseStatePolicy {
    fun recoveryConfirmation(responseType: String): AgentStreamRecoveryConfirmation {
        return when (responseType) {
            "TEXT_REPLY",
            "ASK_USER",
            "SHOW_OPTIONS",
            "REQUEST_PERMISSION",
            "IMPORT_DOCUMENT_REQUEST",
            "LOOKUP_CONTACT_REQUEST",
            "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST",
            "MAKE_CALL_REQUEST" -> AgentStreamRecoveryConfirmation.PromoteRunning
            "CALL_RESULT",
            "BATCH_CALL_RESULT" -> AgentStreamRecoveryConfirmation.TerminalNoPromote
            else -> AgentStreamRecoveryConfirmation.None
        }
    }

    fun textReply(
        state: Index9AssistantUiState,
        statusText: String
    ): Index9AssistantUiState {
        return state.copy(
            stage = AssistantStage.Clarifying,
            processingTurn = false,
            loading = false,
            error = null,
            status = statusText,
            agentQuestions = null,
            agentPermissionRequest = null,
            agentDocumentRequest = null,
            agentDocumentImporting = false,
            agentPendingToolCallId = null
        )
    }

    fun voiceRecovery(
        state: Index9AssistantUiState,
        statusText: String,
        resetManualPause: Boolean = false,
        clearDocumentImporting: Boolean = true
    ): Index9AssistantUiState {
        return AgentStreamErrorUiStateReducer.applyVoiceRecovery(
            state = state,
            statusText = statusText,
            resetManualPause = resetManualPause,
            clearDocumentImporting = clearDocumentImporting
        )
    }

    fun executionError(
        state: Index9AssistantUiState,
        errorText: String,
        statusText: String,
        clearDocumentImporting: Boolean = true
    ): Index9AssistantUiState {
        return AgentStreamErrorUiStateReducer.applyExecutionError(
            state = state,
            errorText = errorText,
            statusText = statusText,
            clearDocumentImporting = clearDocumentImporting
        )
    }

    fun unknownErrorText(responseType: String): String = "未知响应类型: $responseType"
}
